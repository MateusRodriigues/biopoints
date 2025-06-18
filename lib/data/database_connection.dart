import 'package:mysql1/mysql1.dart';

class DatabaseConnection {
  static final DatabaseConnection instance = DatabaseConnection._();
  DatabaseConnection._();

  MySqlConnection? _connection;

  Future<MySqlConnection> get connection async {
    if (_connection != null) return _connection!;
    final settings = ConnectionSettings(
      host: 'biopoints.com.br',
      port: 3306,
      user: 'biopoints_sistema',
      password: 'B!0pO!nt\$2@24', // lembre de escapar o '$' se necessário
      db: 'biopoints_sistema',
    );
    _connection = await MySqlConnection.connect(settings);
    return _connection!;
  }

  Future<Map<String, dynamic>?> loginUser(
      String email, String hashedPassword) async {
    final conn = await connection;
    var results = await conn.query(
      'SELECT * FROM usuarios WHERE u_email = ? AND u_senha = ? LIMIT 1',
      [email, hashedPassword],
    );
    for (var row in results) {
      return row.fields;
    }
    return null;
  }
}
