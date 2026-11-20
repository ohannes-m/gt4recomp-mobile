# GT4 v2.00: integracao local de EE com hooks e VU0/VU1

Esta etapa usa um pacote **privado**, produzido a partir dos C++ que o proprio dono extraiu/recompilou localmente.
O pacote nao deve ser anexado a issues, commits, Actions ou releases publicos. Nenhum dado do jogo foi incluido neste repositorio.

## Resultado confirmado com os arquivos disponibilizados pelo dono

- 328 fontes EE: 326 `unit_*.cpp`, `table.cpp` e `units.hpp`.
- Seis unidades EE receberam apenas os 14 pontos de hooks descritos por `scripts/camera360_units.py` para v2.00.
- A traducao original possui uma diferenca na tabela de entradas do controle analogico: chama
  `unit_00CE(c, 45u)` onde a traducao rc14b chama `unit_00CE(c, 49u)`.
  A integracao preserva **45u** ao adicionar o hook, pois o endereco de destino convidado e a linha de retorno
  permanecem os mesmos. Nao substitua cegamente esse indice.
- A aplicacao dos hooks foi reversivel *byte a byte*; os outros 322 arquivos EE permaneceram inalterados.
- VU0: 14 programas, `vu0_generated.cpp` e manifesto verificados por SHA-256.
- VU1: 2.048 programas, `vu1_generated.cpp`, 128 partes e manifesto verificados por SHA-256.
- O pacote resultante e o manifesto de hashes das seis unidades EE modificadas permanecem **fora do GitHub**.

Essas conferencias sao estruturais e de integridade: **nao** demonstram compilacao Android, compatibilidade
funcional com o runtime rc14b, inicializacao do jogo nem FPS.

## Como o pacote e consumido pela receita Android

Extraia o pacote privado em qualquer lugar do computador, preservando:

```text
GT4_PRIVADO_NAO_PUBLICAR/
  EE_hooked/
    unit_*.cpp
    table.cpp
    units.hpp
  EE_hooked.camera360-units.json
  VU0/
    vu0_generated.cpp
    manifest.json
  VU1/
    vu1_generated.cpp
    vu1_generated_000.cpp ... vu1_generated_127.cpp
    manifest.json
```

Abra `cmd` na raiz do repositorio e execute, quando necessario:

```bat
android\integrar-ee-vu-privado.cmd "C:\CAMINHO\GT4_PRIVADO_NAO_PUBLICAR" --check
```

So depois de **todas** as dependencias privadas e ferramentas estarem presentes, o mesmo comando aceita
`--build-native` para compilar `libgt4.so`. O script encaminha as quatro variaveis
`GT4_EE_UNITS_DIR`, `GT4_EE_UNITS_MANIFEST`, `GT4_VU0_GENERATED_DIR` e `GT4_VU1_GENERATED_DIR`
para a receita oficial. Ele nao executa ADB, nao instala apps e nao envia arquivos para a nuvem.

### Bloqueios restantes

Os C++ privados reunidos **nao** incluem o checkout pinado de `private/references/ps2-web-recomp`,
as capsulas adaptadas do runtime de PS2/IOP (PORT, performance, guarda de licenca, memory card,
IPU, SPU2), o SDK/NDK, SDL3 3.4.18 nem os shaders CoreGS C++. Esses requisitos sao independentes
dos arquivos EE/VU e nao podem ser inventados ou substituidos por um APK falso.

No Android, o CMake confere hashes do manifesto EE e das capsulas antes da compilacao; o script
de integracao nao remove nem contorna essas verificacoes.
