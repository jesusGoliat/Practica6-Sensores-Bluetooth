/// Lista blanca de recursos y dominios del contrato (docs/diseno-p6.md).
library;

/// Recurso de prueba documentado.
class RecursoPrueba {
  /// Crea un recurso.
  const RecursoPrueba(this.url, this.descripcion);

  /// URL completa HTTPS.
  final String url;

  /// Descripción corta en español.
  final String descripcion;
}

/// Dominios permitidos y recursos de prueba.
class ListaBlanca {
  /// Crea una lista con [dominios] permitidos.
  const ListaBlanca({required this.dominios, this.recursos = const []});

  /// Hosts permitidos (minúsculas, puerto 443).
  final Set<String> dominios;

  /// Recursos de prueba sugeridos en la barra de dirección.
  final List<RecursoPrueba> recursos;

  /// `true` si [host] está permitido.
  bool permite(String host) => dominios.contains(host.toLowerCase());

  /// Lista del contrato.
  static const ListaBlanca contrato = ListaBlanca(
    dominios: {
      'jsonplaceholder.typicode.com',
      'httpbin.org',
      'api.github.com',
      'www.ipn.mx',
    },
    recursos: [
      RecursoPrueba('https://jsonplaceholder.typicode.com/todos/1', 'JSON: tarea de ejemplo'),
      RecursoPrueba('https://jsonplaceholder.typicode.com/posts/1', 'JSON: publicación'),
      RecursoPrueba('https://jsonplaceholder.typicode.com/users/1', 'JSON: usuario'),
      RecursoPrueba('https://httpbin.org/json', 'JSON: documento de ejemplo'),
      RecursoPrueba('https://httpbin.org/uuid', 'JSON: UUID aleatorio'),
      RecursoPrueba('https://httpbin.org/image/jpeg', 'Imagen JPEG (~35 KB)'),
      RecursoPrueba('https://api.github.com/zen', 'Texto: aforismo de GitHub'),
      RecursoPrueba('https://www.ipn.mx/robots.txt', 'Texto: robots.txt del IPN'),
    ],
  );
}
