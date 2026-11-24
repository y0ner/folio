# Folio

Visor minimalista para Android de **PDF, Word, Excel y PowerPoint**. Solo
muestra documentos y funciona 100 % sin conexión.

## Ejecutar

```bash
./run.sh android      # en el celular conectado por USB (adb)
./run.sh linux        # en el escritorio (Word/Excel/PowerPoint solo en Android)
./run.sh install      # APK release instalada en el celular
./run.sh apk          # solo compila el APK release
./run.sh test         # pruebas
./run.sh analyze      # análisis estático
```

En Linux, el WebView que usan Word, Excel y PowerPoint necesita WPE WebKit,
que no está en los repositorios de Linux Mint 22. Por eso se reemplaza con un
paquete vacío (`packages/inappwebview_linux_stub`): en escritorio esos tipos
muestran "Formato no compatible" y el resto (inicio, PDF, ajustes) funciona.

## Stack

Flutter · pdfrx (PDFium) para PDF · docx-preview, SheetJS y pptx-preview
empaquetados en `assets/engines/` para Office, en un WebView sin red.

## Documentación

- Diseño: [`docs/diseno.md`](docs/diseno.md)
- Reglas para agentes: [`AGENTS.md`](AGENTS.md) · briefs en `docs/agentes/briefs/`
- Licencias de terceros: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
