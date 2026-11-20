# Redmi Note 10S: caminho para inicializar o GT4 real

## Decisao tecnica: o jogo, nao os probes PanVK

- O repositorio do jogo fornece a arquitetura para libgt4.so: EE recompilado, VU0/VU1 AOT, runtime PS2, IOP, CoreGS e launcher Android.
- Primeiro boot no Mali-G76 MC4: usar o renderizador ARMSX2 GS com OpenGL ES. O modo Auto do ARMSX2 ja prefere GLES nessa geracao Mali.
- O driver PanVK r10 dos APKs de diagnostico NAO esta integrado a libgt4.so ou a apresentacao do jogo. Os testes do cubo e do alpha blending nao comprovam boot.
- Nao repetir testes genericos de GPU. Proxima verificacao no aparelho: tentar iniciar o GT4 em um APK com libgt4.so + libgt4gs.so reais.

## Marco atual: runtime publico reproduzivel (2026-11-20)

O runtime MIT de `snuri00/ps2-web-recomp` foi reproduzido no commit fixado
`1b4808793a12c45125262fd2d5f50a9ec9f7c020`, sem codigo do jogo:

- `slice200-port`: adaptador grafico derivado e uma **nova variante Android** de `main.cpp`, com
  hash proprio em `docs/inputs/android-redmi-public-port-main.json`;
- `slice262-frame-cost-runtime`: sete fontes verificadas contra o manifesto;
- `slice376-frame-render-license-guard-runtime`: tres fontes verificadas;
- `slice200-memcard-runtime`, `slice365-ipu-fast-runtime`, `slice396-spu2-runtime`:
  derivados dos arquivos do donor publicamente fixado, conferidos com seus recibos.

O job Linux compilou sintaticamente o `main.cpp` com Clang/C++20; no Windows, o
`android/preparar-runtime-publico.cmd` executou duas vezes sem sobrescrever
capsulas existentes. **Isso nao e uma compilacao ARM64 nem a execucao do GT4.**
A variante Android mantem os hashes das outras tres fontes do port historico.

No Windows, quando os requisitos publicos forem necessarios, `android\preparar-runtime-publico.cmd`
faz o checkout fixado via Git e deriva os seis grupos em `private/`. So baixa
codigo publico, nao le ISO, ELF, EE ou VU, nao publica arquivo algum e nao instala
programas no celular. A execucao nao recria fontes existentes que ja estejam corretas.

Ainda faltam o conjunto de shaders CoreGS em C++, SDL3 Android, SDK/NDK, ferramentas
do launcher, e **compilar e testar o jogo real** com o pacote privado EE/VU.
Nao tratar a reproducao de runtime como prova de jogabilidade.

## Passo 1: confirmar os insumos reais no Windows, offline

Num clone deste repositorio, use os caminhos que realmente existirem no seu PC; os exemplos de C:\Antigravity sao do ambiente de outra construcao e NAO devem ser assumidos.

~~~bat
set "GT4_ASSETS_ROOT=C:\pasta-do-seu-projeto-com-private"
set "GT4_EE_UNITS_DIR=C:\pasta-das-unidades-ee"
set "GT4_HW_SHADER_CPP_DIR=C:\pasta-dos-shaders-cpp"
set "GT4_VULKAN_INCLUDE=C:\VulkanSDK\VERSAO\Include"
android\redmi-native.cmd
~~~

O comando acima e somente leitura. Mostra [OK] ou [FALTA] para o runtime PS2 fixado, capsulas, EE (~326 unidades), VU0/VU1 AOT, CoreGS, SDL3 e ferramentas Windows. Nao le a ISO, nao usa ADB, nao acessa o telefone, nao cria APK e nao envia dados.

Se retornar FALTA, o proximo trabalho e resolver os arquivos/fontes; um novo teste PanVK nao ajudaria.

## Passo 2: compilar e empacotar o jogo de verdade (local)

Quando os insumos estiverem disponiveis, execute no Windows:

~~~bat
android\redmi-native.cmd --build-apk
~~~

Este comando faz o seguinte, parando ao primeiro erro e sem tocar no celular:

1. Valida os arquivos privados EE/VU, runtime, CoreGS e SDL3.
2. Confirma ferramentas para o APK: Android SDK 36, NDK 26.1, Java, Rust target
   aarch64-linux-android, Tauri CLI e o arquivo privado GT4_ANDROID_SIGNING.
3. Compila libgt4.so de verdade para arm64-v8a e faz staging do SDL3.
4. Compila libgt4gs.so para arm64-v8a com o ARMSX2 GS, OpenGL ES ligado,
   Vulkan desligado e sem JIT. Nenhum PanVK e instalado ou necessario aqui.
5. Faz staging de GameIndex.yaml, shaders e fontes do ARMSX2.
6. Valida que as tres bibliotecas (libgt4.so, libgt4gs.so, libSDL3.so), o SDL3
   AAR e os recursos graficos estao presentes.
7. Empacota o launcher com cargo tauri android build, usando apenas sua chave
   de assinatura local (nunca presente no GitHub).

O candidato gerado fica em:

~~~text
build\redmi-output\GT4Recomp-private-redmi-arm64.apk
~~~

O APK nao e enviado ao GitHub nem instalado automaticamente. Dependencias
publicas das ferramentas Rust/Gradle ainda podem precisar ser baixadas durante
o build no PC, mas arquivos do jogo nao sao enviados.

Para compilar somente a biblioteca principal (sem ARMSX2 e APK):

~~~bat
android\redmi-native.cmd --build-native
~~~

### Assinatura e componentes

A variavel de ambiente GT4_ANDROID_SIGNING deve apontar para o arquivo .properties
com sua chave. O script nao cria, le nem mostra segredos. A chave deve ser a mesma
utilizada em instalacoes anteriores para o Android permitir a atualizacao.

O primeiro build e local e experimental. Falhar na compilacao nao e falha do
driver PanVK. Problemas na inicializacao real devem ser diagnosticados com o
log do proprio jogo, nao com novos cubes demonstrativos.

## Passo 3: verificar no telefone somente quando houver APK real

O launcher deve abrir, permitir a selecao da propria ISO e iniciar o GT4 pelo
GameActivity. A GPU Mali G76 usara o caminho GLES do ARMSX2 para o primeiro boot.
Nao forcar Vulkan experimental nessa etapa.

Todo o material derivado do jogo (ISO, ELF, unidades EE/VU, capsulas privadas,
saves e chave de assinatura) deve ficar local. NAO colocar esses arquivos em
GitHub nem em mensagens.

GATE DE CONCLUSAO: APK gerado localmente, launcher aberto, disco selecionado pelo
usuario e GT4 alcancando os menus no Redmi. Nenhum dos testes PanVK anteriores
comprova esse gate. O workflow do GitHub apenas valida a logica do preflight,
porque os arquivos privados nao estao presentes na nuvem.
