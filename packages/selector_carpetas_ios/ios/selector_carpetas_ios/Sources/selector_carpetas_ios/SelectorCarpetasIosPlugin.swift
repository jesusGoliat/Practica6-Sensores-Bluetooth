import Flutter
import UIKit
import UniformTypeIdentifiers

/// Selector de carpetas para iOS.
///
/// Usa UIDocumentPickerViewController para que el usuario autorice una carpeta
/// fuera del sandbox y guarda un bookmark con alcance de seguridad para poder
/// volver a abrirla en otra sesión. No se pide ningún permiso global.
public class SelectorCarpetasIosPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var resultadoPendiente: FlutterResult?
  private var urlActual: URL?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(
      name: "mx.ipn.escom.p6/selector_carpetas_ios",
      binaryMessenger: registrar.messenger()
    )
    let instancia = SelectorCarpetasIosPlugin()
    registrar.addMethodCallDelegate(instancia, channel: canal)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "elegirCarpeta":
      elegirCarpeta(result: result)
    case "resolver":
      guard
        let argumentos = call.arguments as? [String: Any],
        let token = argumentos["token"] as? String
      else {
        result(FlutterError(code: "argumentos", message: "Falta el token del bookmark.", details: nil))
        return
      }
      resolver(token: token, result: result)
    case "liberar":
      liberar()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func elegirCarpeta(result: @escaping FlutterResult) {
    resultadoPendiente = result
    let selector = UIDocumentPickerViewController(
      forOpeningContentTypes: [.folder],
      asCopy: false
    )
    selector.delegate = self
    selector.allowsMultipleSelection = false
    selector.modalPresentationStyle = .formSheet

    guard let controlador = controladorSuperior() else {
      resultadoPendiente = nil
      result(FlutterError(code: "sin_vista", message: "No hay una vista activa para presentar el selector.", details: nil))
      return
    }
    if let popover = selector.popoverPresentationController {
      popover.sourceView = controlador.view
      popover.sourceRect = CGRect(
        x: controlador.view.bounds.midX,
        y: controlador.view.bounds.midY,
        width: 1,
        height: 1
      )
    }
    controlador.present(selector, animated: true)
  }

  public func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let url = urls.first else {
      resultadoPendiente?(nil)
      resultadoPendiente = nil
      return
    }
    let acceso = url.startAccessingSecurityScopedResource()
    do {
      let datos = try url.bookmarkData(
        options: [.minimalBookmark],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      urlActual = url
      resultadoPendiente?([
        "ruta": url.path,
        "nombre": url.lastPathComponent,
        "token": datos.base64EncodedString(),
        "acceso": acceso,
        "obsoleto": false,
      ])
    } catch {
      if acceso {
        url.stopAccessingSecurityScopedResource()
      }
      resultadoPendiente?(FlutterError(
        code: "bookmark",
        message: "No se pudo guardar el acceso a la carpeta: \(error.localizedDescription)",
        details: nil
      ))
    }
    resultadoPendiente = nil
  }

  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    resultadoPendiente?(nil)
    resultadoPendiente = nil
  }

  private func resolver(token: String, result: @escaping FlutterResult) {
    guard let datos = Data(base64Encoded: token) else {
      result(nil)
      return
    }
    var obsoleto = false
    do {
      let url = try URL(
        resolvingBookmarkData: datos,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &obsoleto
      )
      let acceso = url.startAccessingSecurityScopedResource()
      urlActual = url
      result([
        "ruta": url.path,
        "nombre": url.lastPathComponent,
        "token": token,
        "acceso": acceso,
        "obsoleto": obsoleto,
      ])
    } catch {
      // Un bookmark vencido o de una carpeta eliminada no debe tumbar la app.
      result(nil)
    }
  }

  private func liberar() {
    if let url = urlActual {
      url.stopAccessingSecurityScopedResource()
    }
    urlActual = nil
  }

  private func controladorSuperior() -> UIViewController? {
    let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let ventanas = escenas.flatMap { $0.windows }
    var controlador = (ventanas.first { $0.isKeyWindow } ?? ventanas.first)?.rootViewController
    while let presentado = controlador?.presentedViewController {
      controlador = presentado
    }
    return controlador
  }
}
