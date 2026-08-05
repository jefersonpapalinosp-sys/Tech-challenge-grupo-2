# Evidências — Aplicação rodando na AWS

Capturas de tela da API **ToggleMaster** em execução na **EC2** (`54.237.129.141:5000`,
região us-east-1), conectada ao **RDS PostgreSQL**. Feitas com o navegador (Chromium) contra
o IP público da instância.

| Arquivo | O que mostra |
| :------ | :----------- |
| [app-health.png](app-health.png) | `GET /health` → `{"status":"ok"}` (aplicação no ar) |
| [app-flags.png](app-flags.png) | `GET /flags` → lista lida do **RDS** (prova a conexão com o banco) |
| [app-flag-especifica.png](app-flag-especifica.png) | `GET /flags/video-demo` → consulta de uma flag específica |

> Para o vídeo, recomenda-se também capturar: (1) a app rodando **localmente** com Docker,
> (2) a instância EC2 e o RDS no **console AWS**, e (3) as regras dos **Security Groups**
> (a entrada 5432 do RDS com origem no SG da EC2).
