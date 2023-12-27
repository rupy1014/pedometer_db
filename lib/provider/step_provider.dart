import 'package:flutter/cupertino.dart';
import 'package:pedometer/pedometer.dart';
import 'package:pedometer_db/model/step.dart';
import 'package:sqflite/sqflite.dart';

final String tableName = 'steps';



class StepProvider {
  Database? db;
  // Stream<StepCount>? _stepCountStream;

  Future initDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = "$databasesPath/pedometer_db.db";
    db = await openDatabase(
      path,
      version: 1,
      onConfigure: (Database db) => {},
      onCreate: (Database db, int version) => _createDatabase(db, version),
      onUpgrade: (Database db, int oldVersion, int newVersion) => {},
    );
  }


  Future _createDatabase(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS steps (
      id INTEGER PRIMARY KEY,
      delta_steps INTEGER NOT NULL,
      steps INTEGER NOT NULL,
      timestamp INTEGER NOT NULL
    )
  ''');

    //create index
    await db.execute('''
    CREATE INDEX idx_timestamp ON steps (timestamp ASC)
    ''');
  }


  Future<int?> insertData(StepCount event) async {
    Step? lastStep = await getLastStep();

    int delta_steps = 0;
    int steps = event.steps;
    int timestamp = event.timeStamp.millisecondsSinceEpoch;

    //어플 처음 실행이 아닐 경우
    if(lastStep != null) {
      //재부팅이 되었을 경우, 재부팅 시점의 걸음값을 정확히 모르는 상태에서 초기화 해야함
      if((lastStep.steps ?? 0) > event.steps) {
        delta_steps = event.steps;
        steps = (lastStep.steps ?? 0) + event.steps;
      } else {
        //재부팅이 되지 않고 계속 쌓일 경우
        delta_steps = event.steps - (lastStep.steps ?? 0);
      }
    }

    debugPrint("** insertData delta: ${delta_steps}, steps: ${steps}, lastStep: ${lastStep?.steps}");

    return await db?.insert(
      tableName,  // table name
      {
        'delta_steps': delta_steps,
        'steps': steps,
        'timestamp': timestamp,
      },  // new post row data
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

  }


  Future<int> queryPedometerData(int startTime, int endTime) async {
    //db 범위밖 1개씩 가져와서 데이터를 조합해야함
    List<Map<String, Object?>>? firstMaps = await db?.rawQuery('SELECT * from $tableName where timestamp < $startTime ORDER BY id desc limit 1');
    List<Map<String, Object?>>? lastMaps = await db?.rawQuery('SELECT * from $tableName where timestamp > $endTime limit 1');

    Step? firstStep;
    Step? lastStep;
    bool firstNoExist = false; //조회일 이전의 값이 db상 없을때, 앱 설치 이전에 값을 조회하는 것이므로 첫번째 값을 가져오는데 활용
    bool lastNoExist = false; //조회일 마지막 값이 db상 없을때, 현재시간 이후의 값을 가져오는 것과 같으므로 마지막 값을 가져오는데 활용

    if(firstMaps != null && firstMaps.isEmpty) {
      //db상 첫번째 데이터를 가져온다
      firstNoExist = true;
      firstMaps = await db?.rawQuery('SELECT * from $tableName limit 1');
    }
    if(firstMaps != null && firstMaps.isNotEmpty) {
      firstStep = Step.fromMap(firstMaps.first);
    }

    if(lastMaps != null && lastMaps.isEmpty) {
      //db상 마지막 데이터를 가져온다
      lastNoExist = true;
      lastMaps = await db?.rawQuery('SELECT * from $tableName ORDER BY id desc limit 1');
    }
    if(lastMaps != null && lastMaps.isNotEmpty) {
      lastStep = Step.fromMap(lastMaps.first);
    }

    debugPrint("** lastStep: ${lastStep?.steps}, fristStep: ${firstStep?.steps}");
    //값 없을때 예상값 조회 시간 보정
    if(firstNoExist) { startTime = firstStep?.timestamp ?? startTime; }
    if(lastNoExist) { endTime = lastStep?.timestamp ?? endTime; }

    int realDataStep = (lastStep?.steps ?? 0) - (firstStep?.steps ?? 0);
    int realDataDuration = (lastStep?.timestamp ?? 0) - (firstStep?.timestamp ?? 0);
    if(realDataDuration == 0) realDataDuration = 1; //0으로 나누지 않게 예외처리

    double percent = (endTime - startTime) / realDataDuration; //예상 데이터를 구하기 위한 환산된 비율
    //기록 걸음수

    debugPrint("** startTime: $startTime, endTime: $endTime, diff: ${endTime - startTime}, realDataStep: ${realDataStep}, realDataTimestamp: ${realDataDuration}, percent: $percent");

    return (realDataStep * percent).toInt(); //예상값 리턴
  }



  Future<Step?> getLastStep() async {
    List<Map<String, Object?>>? maps = await db?.rawQuery('SELECT * from $tableName ORDER BY id DESC limit 1');
    if (maps == null) return null;
    if (maps.isEmpty) return null;
    return Step.fromMap(maps.first);
  }

  Future<int?> delete(int id) async {
    return await db?.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int?> update(Step step) async {
    return await db?.update(tableName, step.toMap(),
        where: 'id = ?', whereArgs: [step.id]);
  }

  Future close() async => db?.close();
}
