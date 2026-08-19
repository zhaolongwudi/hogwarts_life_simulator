class WorldState {
  String academicYear;
  String term;
  String month;
  int dayOfMonth;
  String dayOfWeek;
  String era;
  Map<String, int> housePoints;
  List<String> recentEvents;
  double playerImpactScore;

  WorldState({
    this.academicYear = '1991-1992',
    this.term = 'first',
    this.month = 'September',
    this.dayOfMonth = 1,
    this.dayOfWeek = 'Tuesday',
    this.era = 'harry_same',
    this.housePoints = const {
      'Gryffindor': 350,
      'Slytherin': 350,
      'Ravenclaw': 350,
      'Hufflepuff': 350,
    },
    this.recentEvents = const [],
    this.playerImpactScore = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'academic_year': academicYear,
        'term': term,
        'month': month,
        'day_of_month': dayOfMonth,
        'day_of_week': dayOfWeek,
        'era': era,
        'house_points': housePoints,
        'recent_events': recentEvents,
        'player_impact_score': playerImpactScore,
      };

  factory WorldState.fromJson(Map<String, dynamic> json) => WorldState(
        academicYear: json['academic_year'] ?? '1991-1992',
        term: json['term'] ?? 'first',
        month: json['month'] ?? 'September',
        dayOfMonth: json['day_of_month'] ?? 1,
        dayOfWeek: json['day_of_week'] ?? 'Tuesday',
        era: json['era'] ?? 'harry_same',
        housePoints: Map<String, int>.from(json['house_points'] ?? {}),
        recentEvents: List<String>.from(json['recent_events'] ?? []),
        playerImpactScore: (json['player_impact_score'] ?? 0.0).toDouble(),
      );
}
