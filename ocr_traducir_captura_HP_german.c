#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <unistd.h>

#define BUF_SIZE 8192

// Ejecuta comando y captura salida
char *exec_cmd(const char *cmd) {
  static char buffer[BUF_SIZE];
  FILE *fp = popen(cmd, "r");
  if (!fp)
    return NULL;

  size_t len = 0;
  buffer[0] = '\0';

  while (fgets(buffer + len, BUF_SIZE - len, fp)) {
    len = strlen(buffer);
    if (len >= BUF_SIZE - 1)
      break;
  }

  pclose(fp);

  if (len == 0)
    return NULL;

  // Limpiar saltos de línea finales (típicos de salidas de comandos)
  while (len > 0 && (buffer[len - 1] == '\n' || buffer[len - 1] == '\r')) {
    buffer[--len] = '\0';
  }

  return buffer;
}

int main() {
  // -----------------------
  // 1. CAPTURA Y OCR (Inglés)
  // -----------------------
  printf("Selecciona el área...\n");

  const char *ocr_cmd =
      "scrot -s -o - | "
      "tesseract stdin stdout -l spa+eng --oem 1 --psm 3 2>/dev/null | "
      "tr '\\n' ' ' | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'";

  char *ocr_res = exec_cmd(ocr_cmd);
  if (!ocr_res || strlen(ocr_res) == 0) {
    fprintf(stderr, "[!] OCR vacío o fallido.\n");
    return 1;
  }

  // Copiamos el texto porque exec_cmd usa un buffer estático y lo reusaremos
  char *text = strdup(ocr_res);
  printf("Texto detectado: %s\n", text);

  // -----------------------
  // 2. TRADUCCIÓN (googletrans-de)
  // -----------------------
  printf("Traduciendo (googletrans-de)...\n");

  char trans_cmd[BUF_SIZE + 512];
  snprintf(trans_cmd, sizeof(trans_cmd),
           "$HOME/googletrans/dist/googletrans-de \"%s\" 2>/dev/null", text);

  char *trans_res = exec_cmd(trans_cmd);
  if (!trans_res || strlen(trans_res) == 0) {
    fprintf(stderr, "[!] Traducción fallida.\n");
    free(text);
    return 1;
  }

  char *translated_text = strdup(trans_res);
  printf("Traducción: %s\n", translated_text);

  // -----------------------
  // 3. TTS (Piper German) y OSD
  // -----------------------
  printf("Procesando TTS y OSD (German)...\n");

  // Lockfile para evitar solapamiento de audio de capturas seguidas
  int lock_fd = open("/tmp/ocr_traducir_german.lock", O_CREAT | O_RDWR, 0666);
  if (lock_fd != -1) {
    flock(lock_fd, LOCK_EX);
  }

  const char *version = "de_DE-thorsten-high.onnx";
  const char *tmp_wav = "/tmp/piper_ocr_german.wav";

  // 3.1 Generar audio usando Piper
  char gen_cmd[BUF_SIZE + 512];
  snprintf(gen_cmd, sizeof(gen_cmd),
           "$HOME/piper/piper --model $HOME/piper/%s --output_file \"%s\" "
           ">/dev/null 2>&1",
           version, tmp_wav);

  FILE *gen_fp = popen(gen_cmd, "w");
  if (gen_fp) {
    fprintf(gen_fp, "%s", translated_text);
    pclose(gen_fp);
  }

  // 3.2 Mostrar OSD con osd_cat (Usando archivos para máxima fiabilidad)
  if (strcmp(version, "de_DE-thorsten-high.onnx") == 0) {
    { int r = system("killall osd_cat 2>/dev/null"); (void)r; }

    // Guardamos el texto en un temporal
    FILE *f_tmp = fopen("/tmp/osd_text.tmp", "w");
    if (f_tmp) {
      fprintf(f_tmp, "%s", translated_text);
      fclose(f_tmp);
    }

    // Generamos el formato (ancho 30 para mejor lectura)
    const char *build_format = "cat /tmp/osd_text.tmp | fold -s -w 30 > /tmp/osd_format.tmp";
    { int r = system(build_format); (void)r; }

    char hack_cmd[BUF_SIZE];
    snprintf(hack_cmd, sizeof(hack_cmd),
        "FONT='-*-*-bold-r-*-*-36-*-*-*-*-*-*-*'; "
        "FONT_BARS='-*-*-bold-r-*-*-18-*-*-*-*-*-*-*'; "
        "OFFSET=45; Grosor=12; "
        "FILE='/tmp/osd_format.tmp'; "
        "osd_cat --font=\"$FONT\" --colour=white --align=center --pos=bottom --delay=20 --offset=$OFFSET --outline=$Grosor --outlinecolour=white < \"$FILE\" & "
        "sed 's/./|/g' \"$FILE\" | osd_cat --font=\"$FONT_BARS\" --colour=white --align=center --pos=bottom --delay=20 --offset=$OFFSET --outline=4 --outlinecolour=white & "
        "( sleep 0.1; osd_cat --font=\"$FONT\" --colour=black --align=center --pos=bottom --delay=20 --offset=$OFFSET --outline=$Grosor --outlinecolour=white < \"$FILE\" ) & ");

    { int r = system(hack_cmd); (void)r; }
  }

  // 3.3 Reproducir el audio con mpv
  char play_cmd[512];
  snprintf(play_cmd, sizeof(play_cmd),
           "mpv --volume=50 --no-terminal --quiet \"%s\"", tmp_wav);
  { int r = system(play_cmd); (void)r; }

  // 3.4 Limpiar el OSD después de la reproducción
  { int r = system("killall osd_cat 2>/dev/null"); (void)r; }

  if (lock_fd != -1) {
    flock(lock_fd, LOCK_UN);
    close(lock_fd);
  }

  free(text);
  free(translated_text);

  return 0;
}

// Compilar con:
// gcc -Ofast -march=native -Wall -Wextra -o ocr_traducir_captura_HP ocr_traducir_captura_HP_german.c
