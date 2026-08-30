import 'package:flick/services/library_scanner_service.dart';
import 'package:test/test.dart';

void main() {
  group('chooseAndroidScanEngine', () {
    test('all-files access with readable path routes to Rust walk', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: true,
          useDeepScan: false,
          isRemovable: false,
        ),
        'rust',
      );
    });

    test('all-files access covers removable volumes too', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: true,
          useDeepScan: false,
          isRemovable: true,
        ),
        'rust',
      );
    });

    test('all-files access collapses the deep-scan flag', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: true,
          useDeepScan: true,
          isRemovable: true,
        ),
        'rust',
      );
    });

    test('all-files access without readable path falls back to SAF', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: false,
          useDeepScan: false,
          isRemovable: true,
        ),
        'saf',
      );
    });

    test('scoped normal scan with path uses MediaStore', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: true,
          useDeepScan: false,
          isRemovable: false,
        ),
        'mediaStore',
      );
    });

    test('scoped deep scan on primary uses Rust', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: true,
          useDeepScan: true,
          isRemovable: false,
        ),
        'rust',
      );
    });

    test('scoped deep scan on removable prefers MediaStore', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: true,
          useDeepScan: true,
          isRemovable: true,
        ),
        'mediaStore',
      );
    });

    test('scoped scan without path uses SAF', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: false,
          useDeepScan: false,
          isRemovable: false,
        ),
        'saf',
      );
    });
  });
}
