# Redmi Note 10S: caminho para inicializar o GT4 real

## Decisao tecnica: o jogo, nao os probes PanVK

- O repositorio do jogo fornece a arquitetura para libgt4.so: EE recompilado, VU0/VU1 AOT, runtime PS2, IOP, CoreGS e launcher Android.
- Primeiro boot no Mali-G76 MC4: usar o renderizador ARMSX2 GS com OpenGL ES. O modo Auto do ARMSX2 ja prefere GLES nessa geracao Mali.
- O driver PanVK r10 dos APKs de diagnostico NAO esta integrado a libgt4.so ou a apresentacao do jogo. Os testes do cubo e do alpha blending nao comprovam boot.
- Nao repetir testes genericos de GPU. Proxima verificacao no aparelho: tentar iniciar o GT4 em um APK com libgt4.so + libgt4gs.so reais.

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

## Passo 2: compilar a biblioteca real para ARM64

Somente com todos os insumos presentes:

~~~bat
android\redmi-native.cmd --build-native
~~~

O comando compila libgt4.so para ARM64 e faz o staging dela e do SDL3. Para evitar esgotar RAM, usa um processo de compilacao por vez por padrao, ajustavel pela variavel CMAKE_BUILD_PARALLEL_LEVEL. Ainda nao e um APK jogavel.

## Passo 3: integrar GS Android e APK

Compilar libgt4gs.so com android/armsx2gs e fazer staging com android/stage-armsx2gs.cmd, incluindo GameIndex.yaml, shaders e fontes. Empacotar o launcher Tauri e assinar o APK conforme android/README.md.

O launcher Android ja oferece ARMSX2 como padrao e sua regra Auto escolhe a API a partir da GPU. No Redmi, o primeiro boot segue GLES, sem forcar PanVK.

Todo o material derivado do jogo (ISO, ELF, unidades EE/VU, capsulas privadas, saves e chave de assinatura) deve ficar local. NAO colocar esses arquivos em GitHub, nem em logs ou mensagens.

GATE DE CONCLUSAO: um APK real empacotado e assinado, launcher iniciado, ISO selecionada pelo usuario e GT4 alcancando menus no Redmi. Nada disso esta comprovado so por ter compilado o preflight.
