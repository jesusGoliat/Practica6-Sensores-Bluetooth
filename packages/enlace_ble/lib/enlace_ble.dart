/// Protocolo de enlace (puro Dart) y transporte BLE de la Práctica 6.
library;

export 'src/protocolo/control_duplicados.dart';
export 'src/protocolo/enlace.dart';
export 'src/protocolo/errores.dart';
export 'src/protocolo/fragmentacion.dart';
export 'src/protocolo/sobre.dart';
export 'src/protocolo/tipos.dart';
export 'src/protocolo/transporte_bytes.dart';
export 'src/protocolo/transporte_memoria.dart';
export 'src/transporte/cliente_ble.dart';
export 'src/transporte/constantes_ble.dart'
    show
        uuidServicioTexto,
        uuidRxTexto,
        uuidTxTexto,
        idFabricantePruebas,
        codigosApp,
        datosFabricante,
        leerDatosFabricante,
        nombreVisible,
        appDeNombre;
export 'src/transporte/estado_bluetooth.dart';
export 'src/transporte/permisos_ble.dart';
export 'src/transporte/servidor_ble.dart';
