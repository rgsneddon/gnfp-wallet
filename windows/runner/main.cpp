#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  RECT work{};
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0);
  const int width = 1100;
  const int height = 760;
  int x = work.left + ((work.right - work.left) - width) / 2;
  int y = work.top + ((work.bottom - work.top) - height) / 2;
  if (x < work.left) x = work.left;
  if (y < work.top) y = work.top;
  Win32Window::Point origin(x, y);
  Win32Window::Size size(width, height);
  if (!window.Create(L"GNFP Wallet", origin, size)) {
    return EXIT_FAILURE;
  }
  window.Show();
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
