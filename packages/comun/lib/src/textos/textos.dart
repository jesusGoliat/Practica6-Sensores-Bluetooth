/// Textos compartidos. Un solo origen evita que las dos apps digan cosas
/// distintas (lección aprendida de la Tarea 2).
abstract final class T {
  // Navegación y acciones generales
  static const appGestor = 'Archivos IPN';
  static const appJuego = 'Pares IPN';
  static const explorador = 'Explorador';
  static const favoritos = 'Favoritos';
  static const recientes = 'Recientes';
  static const ajustes = 'Ajustes';
  static const inicio = 'Inicio';
  static const partidas = 'Partidas';
  static const cancelar = 'Cancelar';
  static const aceptar = 'Aceptar';
  static const cerrar = 'Cerrar';
  static const guardar = 'Guardar';
  static const eliminar = 'Eliminar';
  static const renombrar = 'Renombrar';
  static const copiar = 'Copiar';
  static const mover = 'Mover';
  static const pegarAqui = 'Pegar aquí';
  static const compartir = 'Compartir';
  static const exportar = 'Exportar';
  static const abrir = 'Abrir';
  static const abrirCon = 'Abrir con…';
  static const buscar = 'Buscar';
  static const reintentar = 'Reintentar';
  static const volver = 'Volver';
  static const listo = 'Listo';

  // Temas
  static const tema = 'Tema';
  static const temaGuinda = 'Guinda IPN';
  static const temaAzul = 'Azul ESCOM';
  static const modoSistema = 'Seguir al sistema';
  static const modoClaro = 'Claro';
  static const modoOscuro = 'Oscuro';
  static const apariencia = 'Apariencia';

  // Archivos
  static const espacioApp = 'Espacio de la app';
  static const carpetasAutorizadas = 'Carpetas autorizadas';
  static const anadirCarpeta = 'Añadir carpeta';
  static const importarArchivo = 'Importar archivo';
  static const nuevaCarpeta = 'Nueva carpeta';
  static const metadatos = 'Metadatos';
  static const soloLectura = 'Solo lectura';
  static const vacio = 'Esta carpeta está vacía';
  static const sinFavoritos = 'Todavía no tienes favoritos';
  static const sinRecientes = 'Todavía no has abierto archivos';
  static const noDisponible = 'No disponible';
  static const permisoRevocado = 'Permiso revocado';
  static const rutaNoDisponible = 'La ruta ya no está disponible';

  // Metadatos
  static const nombre = 'Nombre';
  static const tamano = 'Tamaño';
  static const modificado = 'Modificado';
  static const creado = 'Creado';
  static const tipoMime = 'Tipo MIME';
  static const tipoUt = 'UTType';
  static const ruta = 'Ruta';
  static const origen = 'Origen';

  // Ajustes
  static const vaciarCache = 'Vaciar caché de miniaturas';
  static const cacheMiniaturas = 'Caché de miniaturas';
  static const acercaDe = 'Acerca de';
  static const version = 'Versión';

  // Errores
  static const errorLeer = 'No se pudo leer el archivo';
  static const errorEscribir = 'No se pudo escribir el archivo';
  static const errorPermiso = 'No tienes permiso para esta operación';
  static const errorNoSoportado = 'Operación no disponible para este proveedor';
  static const errorEspacio = 'Espacio insuficiente o el proveedor no permite escribir';
  static const errorCorrupto = 'El archivo está incompleto o dañado';
  static const archivoNoExiste = 'El archivo ya no existe';

  // Juego
  static const jugar = 'Jugar';
  static const continuar = 'Continuar partida';
  static const nuevaPartida = 'Nueva partida';
  static const nivel = 'Nivel';
  static const modo = 'Modo';
  static const relajado = 'Relajado';
  static const contrarreloj = 'Contrarreloj';
  static const campus = 'Campus (4×4)';
  static const laboratorio = 'Laboratorio (6×6)';
  static const puntaje = 'Puntaje';
  static const tiempo = 'Tiempo';
  static const movimientos = 'Movimientos';
  static const progreso = 'Progreso';
  static const mejorPuntaje = 'Mejor puntaje';
  static const partidasJugadas = 'Partidas jugadas';
  static const formatoGuardado = 'Formato de guardado';
  static const gestionarPartidas = 'Gestionar partidas';
  static const verContenido = 'Ver contenido';
  static const etiqueta = 'Etiqueta';
  static const etiquetas = 'Etiquetas';
  static const sinPartidas = 'No hay partidas guardadas';
  static const corrupta = 'Partida dañada';
  static const sonido = 'Sonido';
  static const animaciones = 'Animaciones';
  static const nombreJugador = 'Nombre del jugador';
  static const pausa = 'Pausa';
  static const reanudar = 'Reanudar';
  static const reiniciar = 'Reiniciar';
  static const victoria = '¡Felicidades!';
  static const tiempoAgotado = 'Se acabó el tiempo';
  static const guardarPartida = 'Guardar partida';
  static const cargarPartida = 'Cargar partida';
  static const partidaGuardada = 'Partida guardada';
  static const partidaCargada = 'Partida cargada';
  static const partidaEliminada = 'Partida eliminada';
  static const partidaCorruptaMsg =
      'No se pudo cargar la partida: el archivo está vacío, incompleto o dañado. Las demás partidas siguen intactas.';
}
