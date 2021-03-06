part of database_api;

/*
    "id": "fc2be6bf-cc49-4630-bfdd-712fd6b3e678",
    "losses": {
        "b72f3061-f573-40d7-832a-5ad475bd7909": 34,
        "8d87c468-699a-47a8-b40d-cfb73a5660ad": 12,
        "36569151-a2fb-43c1-9df7-2df512424c82": 39,
        "ca3f1c8c-c025-4d8e-8eef-5be6accbeb16": 40,
        "a37f9158-7f82-46bc-908c-c9e2dda7c33b": 30,
        "9debc64f-74b7-4ae1-a4d6-fce0144b6ea5": 45,
        "3f8bbb15-61c0-4e3f-8e4a-907a5fb1565e": 38,
        "b63be8c2-576a-4d6e-8daf-814f8bcea96f": 48,
        "f02aeae2-5e6a-4098-9842-02d2273f25c7": 41,
        "878c1bf6-0d21-4659-bfee-916c8314d69c": 52,
        "747b8e4a-7e50-4638-a973-ea7950a3e739": 33,
        "eb67ae5e-c4bf-46ca-bbbc-425cd34182ff": 42,
        "105bc3ff-1320-4e37-8ef0-8d595cb95dd0": 38,
        "b024e975-1c4a-4575-8936-a3754a08806a": 40,
        "adc5b394-8f76-416d-9ce9-813706877b84": 33,
        "57ec08cc-0411-4643-b304-0e80dbc15ac7": 42,
        "979aee4a-6d80-4863-bf1c-ee1a78e06024": 52,
        "23e4cbc1-e9cd-47fa-a35b-bfa06f726cb7": 30,
        "bfd38797-8404-4b38-8b82-341da28b1f83": 41,
        "7966eb04-efcc-499b-8f03-d13916330531": 40
    },
    "wins": {
        "b72f3061-f573-40d7-832a-5ad475bd7909": 43,
        "8d87c468-699a-47a8-b40d-cfb73a5660ad": 65,
        "36569151-a2fb-43c1-9df7-2df512424c82": 38,
        "ca3f1c8c-c025-4d8e-8eef-5be6accbeb16": 37,
        "a37f9158-7f82-46bc-908c-c9e2dda7c33b": 47,
        "9debc64f-74b7-4ae1-a4d6-fce0144b6ea5": 32,
        "3f8bbb15-61c0-4e3f-8e4a-907a5fb1565e": 39,
        "b63be8c2-576a-4d6e-8daf-814f8bcea96f": 29,
        "f02aeae2-5e6a-4098-9842-02d2273f25c7": 36,
        "878c1bf6-0d21-4659-bfee-916c8314d69c": 25,
        "747b8e4a-7e50-4638-a973-ea7950a3e739": 44,
        "eb67ae5e-c4bf-46ca-bbbc-425cd34182ff": 35,
        "105bc3ff-1320-4e37-8ef0-8d595cb95dd0": 39,
        "b024e975-1c4a-4575-8936-a3754a08806a": 37,
        "adc5b394-8f76-416d-9ce9-813706877b84": 44,
        "57ec08cc-0411-4643-b304-0e80dbc15ac7": 35,
        "979aee4a-6d80-4863-bf1c-ee1a78e06024": 25,
        "23e4cbc1-e9cd-47fa-a35b-bfa06f726cb7": 47,
        "bfd38797-8404-4b38-8b82-341da28b1f83": 36,
        "7966eb04-efcc-499b-8f03-d13916330531": 37
    }
*/

class Standings {
  final String id;
  final Map<String, int> losses;
  final Map<String, int> wins;
  
  Standings({this.id, this.losses, this.wins});
  
  factory Standings.fromJson(Map<String, dynamic> json){
    var lossesMap = json['losses'] as Map<String, dynamic>;
    Map<String, int> losses = lossesMap.map(
      (k, v) { return new MapEntry(k.toString(), int.parse(v.toString())); });
    var winsMap = json['wins'] as Map<String, dynamic>;  
    Map<String, int> wins = winsMap.map(
      (k, v) { return new MapEntry(k.toString(), int.parse(v.toString())); });
    return Standings(
      id: json['id'] as String,
      losses: losses,
      wins: wins,
    );
  }
  
  @override
  String toString() => "Standings: $id";

}
