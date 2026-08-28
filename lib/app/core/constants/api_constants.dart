/// Constantes de configuração de API
class ApiConstants {
  ApiConstants._();

  // Ambiente detectado via --dart-define=ENV=prod
  static const String environment =
      String.fromEnvironment('ENV', defaultValue: 'prod');

  // Base URLs
  static String get baseUrl {
    switch (environment) {
      case 'dev':
        // Para testes locais, rode: php -S localhost:8080 -t backend/
        return 'http://localhost:8080';
      case 'prod':
      default:
        return 'https://rotaescolar.app.br';
    }
  }

  // Endpoints
  static const String authRegister       = '/api/auth/register.php';
  static const String authProfile        = '/api/auth/profile.php';
  static const String authForgotPassword = '/api/auth/forgot_password.php';

  static const String studentsIndex = '/api/students/index.php';
  static const String studentsUpdate = '/api/students/update.php';

  static const String schoolsIndex = '/api/schools/index.php';
  static const String schoolsCreate = '/api/schools/create.php';

  static const String driversIndex = '/api/drivers/index.php';
  static const String driversProfile = '/api/drivers/profile.php';

  static const String financialIndex = '/api/financial/index.php';
  static const String financialPay = '/api/financial/pay.php';
  static const String financialNotify = '/api/financial/notify.php';

  static const String routesIndex = '/api/routes/index.php';
  static const String routesReorder = '/api/routes/reorder.php';

  static const String evaluationsCreate = '/api/evaluations/create.php';
  static const String evaluationsIndex = '/api/evaluations/index.php';

  static const String uploadFotoCnh = '/api/upload/foto_cnh.php';
  static const String uploadFotoCrlv = '/api/upload/foto_crlv.php';

  static const String locationEstados = '/api/location/estados.php';
  static const String locationMunicipios = '/api/location/municipios.php';
  static const String locationBairros = '/api/location/bairros.php';
  static const String locationBairrosCreate = '/api/location/bairros_create.php';
  static const String locationEscolas = '/api/location/escolas.php';
  static const String locationEscolasCreate = '/api/location/escolas_create.php';

  static const String driverBairros = '/api/drivers/bairros.php';
  static const String driverEscolas = '/api/drivers/escolas.php';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Headers
  static const String contentType = 'application/json';
  static const String authorizationHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer';
}
