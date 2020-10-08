import 'dart:convert';
import 'package:intl/intl.dart';
import 'database_api.dart';

League _league;
Subleague _sub1;
Subleague _sub2;

List<List<TeamStandings>> subStandings;

List<Team> _allTeams;
Season _season;
Standings _standings;
Tiebreakers _tiebreakers;
List<String> _dayOfWeek = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
List<String> _monthOfYear = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
  "Aug", "Sep", "Oct", "Nov", "Dec"];

NumberFormat f = new NumberFormat("#", "en_US");
  
Future<SiteData> calcSiteData() async {
  
  _league = await getLeague();
  _sub1 = await getSubleague(_league.subleagueId1);
  _sub2 = await getSubleague(_league.subleagueId2);
  
  String lastUpdate = getUpdateTime();
  
  SiteData sitedata = new SiteData(lastUpdate, 
    _sub1.id, _sub1.name, 
    _sub2.id, _sub2.name);
  print(sitedata);

  return sitedata;
}  

String getUpdateTime(){
  var now = new DateTime.now();
  f.minimumIntegerDigits = 2;
  return "${_dayOfWeek[now.weekday]} " + 
    "${_monthOfYear[now.month]} " +
    "${now.day} ${f.format(now.hour)}${f.format(now.minute)}";
}

Future<void> calcStats(int season) async {
  print('Beginning stat calculations');
  _season = await getSeason(season);
  _standings = await getStandings(_season.standings);

  _allTeams = await getTeams();
  _tiebreakers = await getTiebreakers(_league.tiebreakersId);

  List<TeamStandings> sub1Standings = await calculateSubLeague(_sub1);
  List<TeamStandings> sub2Standings = await calculateSubLeague(_sub2);
  
  subStandings = [sub1Standings, sub2Standings];
    
}

Future<List<TeamStandings>> calculateSubLeague(Subleague sub) async{
  print("Calculating status for $sub");
  Division div1 = await getDivision(sub.divisionId1);
  Division div2 = await getDivision(sub.divisionId2);
  List<Team> teams = _allTeams.where((t) => 
    div1.teams.contains(t.id) ||
    div2.teams.contains(t.id)).toList();

  
  List<TeamStandings> teamStandings = new List<TeamStandings>();
  teams.forEach((team){
    String divName;
    if(div1.teams.contains(team.id)){
      divName = div1.name.split(' ')[1];
    } else {
      divName = div2.name.split(' ')[1];
    }
    
    TeamStandings standing = 
    new TeamStandings(team.id, team.nickname, divName,
      _standings.wins[team.id], 
      _standings.losses[team.id],
      _tiebreakers.order.indexOf(team.id));
    teamStandings.add(standing);
  });

  //sort first then calculate
  sortTeamsNotGrouped(teamStandings);
  reSortDivLeader(teamStandings);

  calculateGamesBehind(teamStandings);
  calculateMagicNumbers(teamStandings);
  
  return teamStandings;

}

void reSortDivLeader(List<TeamStandings> teamStandings){
  //if the first four teams are the same division, move
  //the other div leader into 4th
  String firstDiv = teamStandings.first.division;
  if(teamStandings.take(4).every((team) =>
    team.division == firstDiv) ||
    teamStandings.take(4).every((team) =>
    team.division != firstDiv)){
    print("Top four teams are the same division");
    //find top of other division
    TeamStandings otherLeader = teamStandings.firstWhere((team) =>
      team.division != firstDiv);
    print("Moving $otherLeader");
    teamStandings.remove(otherLeader);
    teamStandings.insert(3, otherLeader);
  }
    
}

void calculateGamesBehind(List<TeamStandings> teamStandings) {
  //compute games back from Division leaders and Wild Card spot
  Map<String, List<int>> divLeaders = new Map<String, List<int>>();
  String firstDiv = teamStandings[0].division;
  divLeaders[firstDiv] = [
    teamStandings[0].wins - teamStandings[0].losses,
    teamStandings[0].favor];
    
  TeamStandings secondDivLeader = teamStandings.firstWhere((team) =>
    team.division != firstDiv);
  divLeaders[secondDivLeader.division] = [
    secondDivLeader.wins - secondDivLeader.losses,
    secondDivLeader.favor];
    
  int lastPlayoffDiff = teamStandings[3].wins - 
    teamStandings[3].losses;  
  int lastPlayoffOrder = teamStandings[3].favor;    
    
  for (int i = 1; i < teamStandings.length; i++){
    if(teamStandings[i] != secondDivLeader){
      int teamDiff = teamStandings[i].wins - 
        teamStandings[i].losses;
      List divLeader = divLeaders[teamStandings[i].division];
      num gbDiv = ( divLeader[0] - teamDiff ) / 2;
      if (divLeader[1] < teamStandings[i].favor){
        gbDiv += 1;
      }
      teamStandings[i].gbDiv = formatGamesBehind(gbDiv);
      print("GbDiv ${teamStandings[i].gbDiv}");
      
      if(i > 3) {
        num gbWc = ( lastPlayoffDiff - teamDiff ) / 2;
        if (lastPlayoffOrder < teamStandings[i].favor){
          gbWc += 1;
        }
        teamStandings[i].gbWc = formatGamesBehind(gbWc);
        print("GbWc ${teamStandings[i].gbWc}");
      }
    }
  }  
}

void calculateMagicNumbers(List<TeamStandings> teamStandings){
  _calculateWinningMagicNumbers(teamStandings);
  _calculatePartyTimeMagicNumbers(teamStandings);
}

void _calculateWinningMagicNumbers(List<TeamStandings> teamStandings) {
  for (int i = 0; i < teamStandings.length; i++){
    int maxWins = 99 - teamStandings[i].losses;

    //print("${teamStandings[i]} maxWins: $maxWins");
    for (int j = 0; j < i && j < 4; j++){
      teamStandings[i].winning[j] = "DNCD";
      if( maxWins < teamStandings[j].wins ||
        (maxWins == teamStandings[j].wins &&
        teamStandings[i].favor > teamStandings[j].favor)){
        teamStandings[i].winning[j] = "X";
      }
      
    }
    for (int b = i + 1; b < 5; b++){
      //Wb + GRb - Wa + 1
      int magic = teamStandings[b].wins +
        (99 - (teamStandings[b].wins + teamStandings[b].losses)) -
        teamStandings[i].wins;
      if (teamStandings[i].favor > teamStandings[b].favor) {
        //team b wins ties
        magic += 1;
      }
      //print("WinMN for ${teamStandings[i]} vs. ${teamStandings[b]}: $magic");
      if (magic > 0){
        //set magic number
        teamStandings[i].winning[b - 1] = "$magic";
      } else if (b > 1 && 
        teamStandings[i].winning.any((s) => s == "^")) {
        //previous spot guaranteed, so this one can't
        teamStandings[i].winning[b - 1] = "X";
      } else {
        //this spot or better guaranteed
        teamStandings[i].winning[b - 1] = "^";
      }
      
    }
        
    if(teamStandings[i].winning[3] == "^" ||
      teamStandings[i].winning[3] == "X"){
      teamStandings[i].winning[4] = "X";
    } else {
      teamStandings[i].winning[4] = "0";
    }
    
    if(teamStandings[i].winning[0] == "X" &&
      teamStandings[i].winning[1] == "X" &&
      teamStandings[i].winning[2] == "X" &&
      teamStandings[i].winning[3] == "X"){
      teamStandings[i].winning[4] = "PT";
    }
    
  }
}

void _calculatePartyTimeMagicNumbers(List<TeamStandings> teamStandings) {
  for (int i = 0; i < teamStandings.length; i++){
    var stand = teamStandings[i];
    int maxWins = 99 - stand.losses;
    for(int k = 0; k < 5; k++){
      switch(stand.winning[k]){
        case '^':
        case 'X':
        case 'PT':
          stand.partytime[k] = stand.winning[k];
          break;
        default:
          if(i <= k) {
            stand.partytime[k] = "MW";
          } else if (k == 4) {
            stand.partytime[k] = "MW";
          } else {
            //maxWinsi - Wk
            //print("Find Elim: $stand Berth: $k");
            int magic = maxWins - teamStandings[k].wins;
            //if we don't have favor, elim is one lower
            if(stand.favor < teamStandings[k].favor) {
              magic += 1;
            }
            stand.partytime[k] = "$magic";

          }
          
          break;
      } 
    }
  }
}

//sort teams by wins, losses, divine favor
void sortTeamsNotGrouped(List<TeamStandings> teams) {
  teams.sort((a, b) {
    if(b.wins != a.wins){
      return b.wins.compareTo(a.wins);
    } else if (b.losses != a.losses){
      return a.losses.compareTo(b.losses);
    } else {
      return a.favor.compareTo(b.favor);
    }
  });
}

String formatGamesBehind(num gb){
  if(gb == gb.toInt()){
    return gb.toString();
  } else if (gb < 1 ) {
    return "½";
  } else {
    return "${gb.toInt()}½";
  }
}

class TeamStandings {
  final String id;
  final String nickname;
  final String division;
  final wins;
  final losses;
  final int favor;
  
  String gbDiv = '-';
  String gbWc = '-';
  final List<String> po = ['-', '-', '-', '-', '-'];
  final List<String> winning = ['-', '-', '-', '-', '-'];
  final List<String> partytime = ['-', '-', '-', '-', '-'];
  
  TeamStandings(this.id, this.nickname, this.division,
    this.wins, this.losses, this.favor);
    
  Map toJson() => {
    'id': id,
    'nickname': nickname,
    'division': division,
    'wins': wins,
    'losses': losses,
    'favor': favor,
    'gbLg': '-',
    'gbPo': '-',
  };
  
  @override
  String toString() => "Standings: $nickname ($wins - $losses)";
  
}
