import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'calc_stats.dart';
import 'database_api.dart';
import 'site_objects.dart';

SimulationData simData;
Season season;
List<Game> games;
Random rand = new Random(0);

Future<void> calculateChances(List<List<TeamStandings>> subStandings, int numSims) async {
  simData = await getSimulationData();
  season = await getSeason(simData.season);
  print("Getting game data");
  games = await getAllGames(simData.season);
  CompletePostseason postSeason = await getCompletePostseason(simData.season);
    
  //print(games[0]);
  
  runSimulations(games, subStandings, numSims);
  
}

void runSimulations(List<Game> games, List<List<TeamStandings>> standings, 
  int numSims){
  Map<String, TeamSim> sims = mapTeamSims(standings, games);
  
  //simulate season X times and gather results
  Map<String, List<num>> poCounts = new Map<String, List<num>>();
  Map<String, List<num>> postCounts = new Map<String, List<num>>();
  // counts for each league playoff berth and no playoffs
  sims.keys.forEach((key) => poCounts[key] = [0, 0, 0, 0, 0]);
  // counts for ILB champ, ILB series, League series, Round 1, WC Round
  sims.keys.forEach((key) => postCounts[key] = [0, 0, 0, 0, 0]);
  List<List<TeamSim>> simsByLeague = new List<List<TeamSim>>();
  standings.forEach((standingList) {
    List<TeamSim> simList = new List<TeamSim>();
    standingList.forEach((standing) {
      simList.add(sims[standing.id]);
    });
    simsByLeague.add(simList);
  });
  
  for (int count = 0; count < numSims; count++){
    simulateSeason(games, sims);
    simulatePostSeason(simsByLeague);
    if (count % 1000 == 0){
      print("Completed simulation count $count");
    }
    
    //sort and count positions
    simsByLeague.forEach((simLeague) {
      sortTeamSims(simLeague);
      //print("Sorted simleague: $simLeague");
      for (int i = 0; i < simLeague.length; i++){
        switch(i){
          case 0:
          case 1:
          case 2:
          case 3:
            poCounts[simLeague[i].id][i]++;
            break;
          default:
            poCounts[simLeague[i].id][4]++;
            break;
        }
      }
    });
    
    sims.values.forEach((sim) => sim.load());
  }  
  
  //update standings with counts / numSims and formatted
  print("Completed $numSims simulations");
  print(poCounts);
  standings.forEach((standingList) => standingList.forEach((standing) {
    for(int i = 0; i < 5; i++){
      switch(standing.winning[i]){
        case '^':
        case 'X':
        case 'PT':
          standing.po[i] = standing.winning[i];
          break;
        default:
          standing.po[i] = formatPercent(poCounts[standing.id][i] / numSims);
          break;
      }
    }
    //print("Standing ${standing.id} po: ${standing.po}");
  }));
  
}

void simulateSeason(List<Game> games, Map<String, TeamSim> sims){
  //simulate unplayed games
  games.where((g) => !g.gameComplete).forEach((g) {
    TeamSim awaySim = sims[g.awayTeam];
    TeamSim homeSim = sims[g.homeTeam];
    //print("Simulate outcome of $g");
    TeamSim winner = simulateGame(awaySim, homeSim);
    
    if(winner == awaySim){
      awaySim.actualWins++;
      awaySim.wins++;
      homeSim.losses++;
    } else {
      homeSim.actualWins++;
      homeSim.wins++;
      awaySim.losses++;        
    }    
  });
}
  
void simulatePostSeason(List<List<TeamSim>> simsByLeague){
  //simulate complete playoff run
  List<TeamSim> leagueChampSims = new List<TeamSim>();
  
  simsByLeague.forEach((simLeague) {
    sortTeamSims(simLeague);
    
    List<TeamSim> round1Sims = new List<TeamSim>(4);
    round1Sims[0] = simLeague[0];
    round1Sims[1] = simLeague[1];
    round1Sims[2] = simLeague[2];
    
    List<TeamSim> round2Sims = new List<TeamSim>(2);
    
    // wild card round
    // pick a random team not in playoffs and simulate
    int nonPlayoffCount = simLeague.length - 4;
    int wildCardIndex = rand.nextInt(nonPlayoffCount) + 4;
    TeamSim wildCard = simLeague[wildCardIndex];
    //print("WildCard pick $wildCardIndex $wildCard");
    //simulate 3 win series with wild card pic
    TeamSim wildseriesWinner = simulateSeries(simLeague[3], wildCard, 2);
    wildseriesWinner.wcSeries = true;
    round1Sims[3] = wildseriesWinner;
    print("WildCard pick $wildCardIndex $wildCard WildSeriesWinner $wildseriesWinner");
    
    // round 1
    // subleague round
  });
  // ilb round
  
}

TeamSim simulateGame(TeamSim awaySim, TeamSim homeSim){
  //default away chance
  num awayChance = .5;
  if(awaySim.actualWins_save != homeSim.actualWins_save ||
    awaySim.losses_save != homeSim.losses_save){
    //print("Uneven match: ${awaySim.actualWins_save}-${awaySim.losses_save} vs. " +
    //  "${homeSim.actualWins_save}-${homeSim.losses_save}");
    //Pa = (WPa * (1 - WPh)) / 
    // ((WPa * (1 - WPh) + WPh * ( 1 - WPa)))
    num WPa = awaySim.wins_save / (awaySim.losses_save + awaySim.wins_save);
    num WPh = homeSim.wins_save / (homeSim.losses_save + homeSim.wins_save);
    awayChance = (WPa * (1 - WPh)) / 
     ((WPa * (1 - WPh) + WPh * ( 1 - WPa)));
  }
  
  //print("Calculated away win chance: $awayChance");    
  if(rand.nextDouble() < awayChance){
    return awaySim;
  } else {
    return homeSim;        
  }    
  
}

TeamSim simulateSeries(TeamSim awaySim, TeamSim homeSim, int winsNeeded){
  int awayWins = 0;
  int homeWins = 0;
  TeamSim winner;
  while(awayWins < winsNeeded && homeWins < winsNeeded){
    winner = simulateGame(awaySim, homeSim);
    if(winner == awaySim){
      awayWins++;
    } else {
      homeWins++;
    }
  }
  if(awayWins >= winsNeeded){
    return awaySim;
  } else {
    return homeSim;
  }
  
}

Map<String, TeamSim> mapTeamSims(List<List<TeamStandings>> standings, List<Game> games){
  Map<String, TeamSim> sims = new Map<String, TeamSim>();
  standings.forEach((standingsList) {
    standingsList.forEach((standing) {
      int actualWins = games.where((g) =>
        (g.awayTeam == standing.id && g.awayScore > g.homeScore) ||
        (g.homeTeam == standing.id && g.homeScore > g.awayScore)).length;
      TeamSim sim = new TeamSim(standing.id, actualWins,
        standing.wins, standing.losses, standing.favor, standing.division);
      sim.save();
      sims[sim.id] = sim;
    });
  });
  return sims;
}

//sort teams by wins, divine favor
void sortTeamSims(List<TeamSim> teams) {
  teams.sort((a, b) {
    if(b.wins != a.wins){
      return b.wins.compareTo(a.wins);
    } else {
      return a.favor.compareTo(b.favor);
    }
  });
  //if the first four teams are the same division, move
  //the other div leader into 4th
  String firstDiv = teams.first.division;
  if(teams.take(4).every((team) =>
    team.division == firstDiv) ||
    teams.take(4).every((team) =>
    team.division != firstDiv)){
    print("Top four teams are the same division");
    //find top of other division
    TeamSim otherLeader = teams.firstWhere((team) =>
      team.division != firstDiv);
    print("Moving $otherLeader");
    teams.remove(otherLeader);
    teams.insert(3, otherLeader);
  }  
}

String formatPercent(num perc){
  perc *= 100;
  if(perc < 1){
    return "<1%";
  } else if (perc > 99){
    return ">99%";
  } else {
    return "${perc.floor().toString()}%";
  }
}

class TeamSim {
  String id;
  int actualWins;
  int wins;
  int losses;
  int favor;
  String division;
  
  int actualWins_save;
  int wins_save;
  int losses_save;
  
  bool wcSeries = false;
  bool r1Series = false;
  bool slSeries = false;
  bool ilbSeries = false;
  bool ilbChamp = false;
  
  TeamSim(this.id, this.actualWins, this.wins, this.losses,
    this.favor, this.division);
  
  void save(){
    actualWins_save = actualWins;
    wins_save = wins;
    losses_save = losses;
  }
  
  void load(){
    actualWins = actualWins_save;
    wins = wins_save;
    losses = losses_save;
    wcSeries = false;
    r1Series = false;
    slSeries = false;
    ilbSeries = false;
    ilbChamp = false;
  }
  
  String toString() => "$id Wins $wins Record: ($actualWins - $losses) " +
    "Saved: $actualWins_save $wins_save $losses_save";
  
}