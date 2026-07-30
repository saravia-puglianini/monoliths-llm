#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUF_SIZE 8192

// Ejecuta comando y captura salida
char *exec_cmd(const char *cmd) {
    static char buffer[BUF_SIZE];
    FILE *fp = popen(cmd, "r");
    if (!fp) return NULL;

    size_t len = 0;
    buffer[0] = '\0';

    while (fgets(buffer + len, BUF_SIZE - len, fp)) {
        len = strlen(buffer);
        if (len >= BUF_SIZE - 1) break;
    }

    pclose(fp);

    if (len == 0) return NULL;

    // Limpiar saltos de línea finales (típicos de salidas de comandos)
    while (len > 0 && (buffer[len-1] == '\n' || buffer[len-1] == '\r')) {
        buffer[--len] = '\0';
    }

    return buffer;
}

int main() {
    // -----------------------
    // 1. CAPTURA Y OCR
    // -----------------------
    printf("Selecciona el área...\n");
    
    const char *ocr_cmd =
        "scrot -s -o - | "
        "tesseract stdin stdout -l eng --oem 1 --psm 6 2>/dev/null | "
        "tr '\n' ' ' | tr -s ' ' | sed 's/- //g'";

    char *ocr_res = exec_cmd(ocr_cmd);
    if (!ocr_res || strlen(ocr_res) == 0) {
        fprintf(stderr, "[!] OCR vacío o fallido.\n");
        return 1;
    }

    // Copiamos el texto porque exec_cmd usa un buffer estático y lo reusaremos
    char *text = strdup(ocr_res);
    printf("Texto detectado: %s\n", text);

    // -----------------------
    // 2. TRADUCCIÓN
    // -----------------------
    printf("Traduciendo...\n");

    // El usuario indica que ~/googletrans/dist/googletrans-es NO soporta tuberías.
    // Se debe pasar el texto como argumento entre comillas.
    char trans_cmd[BUF_SIZE + 512];
    snprintf(trans_cmd, sizeof(trans_cmd), "$HOME/googletrans/dist/googletrans-es \"%s\"", text);

    char *trans_res = exec_cmd(trans_cmd);
    if (!trans_res || strlen(trans_res) == 0) {
        fprintf(stderr, "[!] Traducción fallida.\n");
        free(text);
        return 1;
    }

    char *translated_text = strdup(trans_res);
    printf("Traducción: %s\n", translated_text);

    // -----------------------
    // 3. TTS (espeak-ng)
    // -----------------------
    // El usuario quiere usar: espeak-ng -v es-mx "..."
    char tts_cmd[BUF_SIZE + 512];
    snprintf(tts_cmd, sizeof(tts_cmd), "espeak-ng -v es-mx \"%s\"", translated_text);
    
    printf("Reproduciendo audio...\n");
    int status = system(tts_cmd);
    
    if (status == -1) {
        fprintf(stderr, "[!] Error al ejecutar espeak-ng.\n");
    }

    free(text);
    free(translated_text);

    return 0;
}

// Compilar con:
// gcc -Ofast -march=native -Wall -Wextra -o ocr_traducir_captura_HP ocr_traducir_captura_HP.c