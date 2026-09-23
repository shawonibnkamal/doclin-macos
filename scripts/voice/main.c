// Private stdin carries notification text. Only local model/output paths are arguments.
#include "sherpa-onnx/c-api/c-api.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
int main(int argc, char **argv) {
  if (argc != 4) return 2;
  umask(0077);
  char text[4097]; size_t n = fread(text, 1, 4096, stdin);
  if (!n || !feof(stdin)) return 2;
  text[n] = 0;
  float speed = strtof(argv[3], NULL);
  if (!(speed >= 0.8f && speed <= 1.5f)) return 2;
  char model[4096], voices[4096], tokens[4096], data[4096], lexicon[4096];
  if (strlen(argv[1]) > 3900) return 2;
  snprintf(model,sizeof(model),"%s/model.int8.onnx",argv[1]);
  snprintf(voices,sizeof(voices),"%s/voices.bin",argv[1]);
  snprintf(tokens,sizeof(tokens),"%s/tokens.txt",argv[1]);
  snprintf(data,sizeof(data),"%s/espeak-ng-data",argv[1]);
  snprintf(lexicon,sizeof(lexicon),"%s/lexicon-us-en.txt",argv[1]);
  SherpaOnnxOfflineTtsConfig cfg = {0};
  cfg.model.kokoro.model=model; cfg.model.kokoro.voices=voices;
  cfg.model.kokoro.tokens=tokens; cfg.model.kokoro.data_dir=data;
  cfg.model.kokoro.lexicon=lexicon; cfg.model.kokoro.length_scale=1.0f;
  cfg.model.num_threads=2; cfg.model.provider="cpu";
  cfg.max_num_sentences=1; cfg.silence_scale=0.2f;
  const SherpaOnnxOfflineTts *tts = SherpaOnnxCreateOfflineTts(&cfg);
  if (!tts) return 3;
  // af_heart: one consistent, warm American English voice.
  const SherpaOnnxGeneratedAudio *audio = SherpaOnnxOfflineTtsGenerate(tts,text,3,speed);
  int ok=audio && audio->n > 0 && SherpaOnnxWriteWave(audio->samples,audio->n,audio->sample_rate,argv[2]);
  if(audio) SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
  SherpaOnnxDestroyOfflineTts(tts);
  return ok ? 0 : 4;
}
