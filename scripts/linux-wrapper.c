// Starts GiolgaiiWoW-bin (the Electron binary next to this file) with
// --no-sandbox. Ubuntu blocks the unprivileged user namespaces Chromium's
// sandbox needs, and the SUID fallback requires root, so without this the app
// aborts on double-click. The launcher only renders its own local page.
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
  char self[PATH_MAX];
  ssize_t n = readlink("/proc/self/exe", self, sizeof self - 1);
  if (n < 0) { perror("readlink"); return 1; }
  self[n] = '\0';

  char bin[PATH_MAX];
  snprintf(bin, sizeof bin, "%s/GiolgaiiWoW-bin", dirname(self));

  char **args = calloc(argc + 2, sizeof *args);
  args[0] = bin;
  args[1] = "--no-sandbox";
  for (int i = 1; i < argc; i++) args[i + 1] = argv[i];
  execv(bin, args);
  perror(bin);
  return 1;
}
