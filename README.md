# AWS ECS — n8n em queue mode

Laboratório Terraform para executar o n8n sobre duas EC2 Graviton, com serviços separados de main, webhook e worker. RDS PostgreSQL armazena workflows e execuções; ElastiCache Valkey mantém a fila interna. CodePipeline recebe o código do GitHub, CodeBuild constrói as imagens ARM64 e entrega pelo ECR.

## Arquitetura

O ALB público distribui o acesso entre main e webhook. As EC2 e tasks ficam em duas subnets privadas, com saída por um NAT Gateway em cada AZ. RDS e Valkey usam duas subnets isoladas. A VPC é criada aqui mesmo.

| Componente | Configuração do sandbox |
| --- | --- |
| ECS sobre EC2 | Duas `t4g.small`, ASG com mínimo 2 e máximo 4 |
| Main | Uma task após o bootstrap, para interface, API e triggers |
| Webhook | Uma task após o bootstrap, para webhooks de produção |
| Worker | Uma task após o bootstrap, para executar os workflows |
| Banco | RDS PostgreSQL `db.t4g.micro`, Single-AZ |
| Fila | ElastiCache Valkey `cache.t4g.micro`, sem réplica |
| Saída | Dois NAT Gateways: um na subnet pública 1a e outro na 1b |
| Entrada | ALB público, ACM e `n8n.chmodluciano.com.br` |

Os três serviços usam a mesma imagem, com os comandos `start`, `webhook` e `worker`. O worker executa workflows; não há container auxiliar nem segunda imagem de aplicação.

Main permanece único: seu deploy encerra a task anterior antes de iniciar a próxima. Há uma interrupção temporária da interface e dos triggers desse processo. Webhook e worker têm serviços e task definitions próprios. Não há SQS, multi-main, WAF ou Lambda.

A retenção de backups do RDS é configurada por `rds_backup_retention_period`, com um dia no sandbox. A tentativa de criar o banco com sete dias foi recusada pelo plano FREE desta conta.

O ASG escala os hosts por meio do Capacity Provider. As quantidades de tasks são informadas em `main_count`, `webhook_count` e `worker_count`. Não há auto scaling desses serviços. As reservas iniciais de memória são 768 MiB para main, 512 MiB para webhook e 1.024 MiB para worker. Ajuste conforme a carga dos workflows.

O Capacity Provider usa o nome `capacity-aws-ecs-n8n-ec2`, pois esse recurso não aceita nomes iniciados por `aws`, `ecs` ou `fargate`.

`docs/` fica reservado ao print da arquitetura que será desenhada no Excalidraw.

As duas rotas privadas usam o NAT da própria zona: privada 1a → NAT 1a → pública 1a; privada 1b → NAT 1b → pública 1b. As subnets de dados permanecem sem rota para a internet.

| Rede | CIDR |
| --- | --- |
| VPC | `10.0.0.0/16` |
| Privada 1a | `10.0.0.0/20` |
| Privada 1b | `10.0.16.0/20` |
| Pública 1a | `10.0.48.0/24` |
| Pública 1b | `10.0.49.0/24` |
| Dados 1a | `10.0.51.0/24` |
| Dados 1b | `10.0.52.0/24` |

## Estrutura

Os arquivos Terraform ficam na raiz e compartilham provider, backend e estado. `variables.tf` contém apenas os nomes das variáveis. Todos os valores de entrada estão em `live/sandbox/terraform.tfvars`. Os CIDRs são literais nos recursos de rede, como no projeto `aws-vpc`. Nomes usam diretamente `var.project_name`, e cada recurso compatível declara suas tags `Name`, `Environment` e `Terraform`; não há tags herdadas do provider nem blocos `locals`.

| Arquivos | Responsabilidade |
| --- | --- |
| `vpc.tf`, `internet_gateway.tf`, `*_subnets.tf`, `nat_gateway.tf` | VPC, subnets e rotas |
| `ecs_cluster.tf`, `ecs_iam.tf`, `ecs_service.tf` | EC2, ASG, Capacity Provider, IAM e serviços |
| `ecs_main_task_definition.tf`, `ecs_webhook_task_definition.tf`, `ecs_worker_task_definition.tf` | Definição de cada papel do n8n |
| `rds.tf`, `elasticache.tf`, `secrets_manager.tf` | Banco, fila e segredos |
| `alb.tf`, `route53.tf`, `security_group.tf` | HTTPS, domínio e regras de rede |
| `codebuild*.tf`, `codepipeline*.tf`, `ecr.tf`, `buildspec.yml` | Build e entrega |
| `templates/ecs_user_data.sh.tftpl` | Configuração do agente ECS nas EC2 |

O build fica inteiro no `buildspec.yml`: autenticação no ECR, build ARM64, push e geração dos arquivos de imagem usados pelo CodePipeline. Durante o build, o Dockerfile baixa diretamente da AWS a cadeia pública de certificados do RDS para dentro da imagem. Não há diretório de certificados no repositório, scripts ou sincronização externa de task definitions.

## Conta e custos

A consulta somente leitura em 20/10/2026, com perfil `sextafeira` e região `us-east-1`, encontrou:

| Item | Resultado na consulta |
| --- | --- |
| Plano | FREE ativo |
| Créditos | US$ 134,32 |
| Expiração | 23/11/2026 às 13:55, horário de Brasília |
| Cota EC2 On-Demand Standard | 16 vCPUs; duas `t4g.small` usam quatro |
| `t4g.small` | 2 vCPUs, 2 GiB, elegível ao Free Tier na API EC2 |
| `t4g.medium` | 2 vCPUs, 4 GiB, não elegível na API EC2 |
| CodeBuild ARM/Small | Cota de 15 builds simultâneos |
| Recursos existentes | Nenhuma EC2 em execução/pendente, RDS, cluster ElastiCache, hosted zone ou conexão CodeConnections |

O catálogo RDS incluía `db.t4g.micro` com PostgreSQL 16 e suporte a Multi-AZ. A AWS CLI 2.22.16 não tinha a operação de consulta do plano; foi usado temporariamente o modelo atualizado da API Free Tier do repositório oficial `boto/botocore`, sem modificar o perfil.

Esses resultados não reservam capacidade nem comprovam todas as permissões de criação. Elegibilidade Free Tier não garante gratuidade do conjunto. ALB, NAT, IPv4 público, EBS, RDS, Valkey, segredos, DNS, logs e builds podem consumir créditos. Confira o saldo antes de aplicar e remova o laboratório depois da gravação.

## Preparar

São necessários Terraform 1.11 ou superior, AWS CLI atualizada e acesso ao repositório GitHub. O build padrão roda no CodeBuild; Docker local só é necessário para builds manuais.

```bash
export AWS_PROFILE=sextafeira
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity
```

Preencha o bucket em `live/sandbox/backend.tfvars`. Ele deve existir, com versionamento, bloqueio público e permissões restritas. O estado contém segredos gerados pelo Terraform; precisa ser protegido. O bucket de artefatos do pipeline é separado e criado por este projeto.

```bash
terraform init -backend-config=live/sandbox/backend.tfvars
terraform fmt -check -recursive
terraform validate
```

Revise os valores em `live/sandbox/terraform.tfvars`. As quantidades dos três serviços começam em zero porque o ECR ainda não tem imagens. Preserve esse zero durante o bootstrap. As EC2 e os demais recursos terão custo mesmo sem tasks.

## Preparar o domínio

O fluxo definido usa HTTPS com `n8n.chmodluciano.com.br`. `dns_zone_name = "chmodluciano.com.br"` cria a zona do domínio inteiro no Route 53; `domain_name = "n8n.chmodluciano.com.br"` define o endereço da aplicação. O registro do domínio permanece no Registro.br, e o Route 53 passa a administrar o DNS. O domínio ainda não é usado para outros serviços.

Na primeira execução, crie apenas a zona para obter seus nameservers antes de validar o certificado:

```bash
terraform plan --var-file=live/sandbox/terraform.tfvars -target=aws_route53_zone.n8n
terraform apply --var-file=live/sandbox/terraform.tfvars -target=aws_route53_zone.n8n
terraform output -json domain_name_servers
```

Os quatro servidores retornados são gerados pela AWS; não vêm do e-mail de compra do domínio. Na tela inicial do Route 53, não é necessário registrar, transferir ou criar outra zona manualmente: o Terraform cria a zona.

No Registro.br, entre na conta, selecione `chmodluciano.com.br` e abra DNS → Alterar servidores DNS. Informe os quatro nomes retornados, um por campo, adicionando campos se necessário, e salve. São nomes de servidores, não endereços IP. Essa etapa substitui os servidores DNS do domínio inteiro pelos servidores da zona raiz criada acima. Não use os servidores de uma zona criada apenas para `n8n.chmodluciano.com.br`.

```bash
dig +short NS chmodluciano.com.br
```

Depois de confirmar a delegação, aplique o projeto completo. O uso de `-target` acima é apenas para essa preparação inicial; as aplicações seguintes usam o projeto inteiro.

```bash
terraform plan --var-file=live/sandbox/terraform.tfvars
terraform apply --var-file=live/sandbox/terraform.tfvars
```

ACM aguarda a validação DNS. O listener HTTP redireciona para HTTPS. O listener HTTPS encaminha para main e a regra de caminhos `/webhook/*` e `/webhook-waiting/*` encaminha para webhook. `/webhook-test/*`, interface e API seguem para main.

O bloco `default_action` permanece porque é obrigatório no recurso de listener do ALB. Ele contém somente a ação efetiva de cada listener, sem alternativas condicionais nem resposta 403 de fallback.

## GitHub e primeira entrega

```bash
terraform output -raw github_connection_arn
terraform output -raw pipeline_name
```

No console AWS, abra Developer Tools → Settings → Connections e conclua a autorização GitHub da conexão criada. Ela precisa passar de `PENDING` para `AVAILABLE`.

Envie o código para a branch configurada. O Terraform não faz o push. Depois da autorização, inicie o pipeline pelo console ou pela CLI:

```bash
aws codepipeline start-pipeline-execution --name "$(terraform output -raw pipeline_name)"
```

A entrega segue Source → Build → Deploy. O estágio Deploy atualiza main, webhook e worker em paralelo, com uma ação para cada serviço ECS. A entrega não é uma transação única dos três serviços.

O CodeBuild publica uma imagem n8n, compartilhada pelos serviços main, webhook e worker. A tag combina commit e número do build, por exemplo `a1b2c3d4e5f6-1`. Ela aparece nos logs e no artefato `release.json`. Imagens são imutáveis, sem `latest`.

Depois do primeiro pipeline concluído, atualize em `live/sandbox/terraform.tfvars`:

```hcl
image_tag     = "TAG_PUBLICADA_PELO_BUILD"
main_count    = 1
webhook_count = 1
worker_count  = 1
```

```bash
terraform plan --var-file=live/sandbox/terraform.tfvars
terraform apply --var-file=live/sandbox/terraform.tfvars
terraform output -raw n8n_url
```

Abra a URL e crie o usuário proprietário. Mantenha `main_count = 1`; este projeto não usa multi-main.

## Entregas seguintes

O pipeline publica revisões das task definitions para atualizar imagens. Terraform também gerencia essas definições e as referências dos serviços. **Antes de cada novo apply, atualize `image_tag` com a última tag entregue pelo pipeline.** Isso mantém a configuração declarada alinhada à imagem em execução. Se informar uma tag anterior, Terraform voltará os serviços para aquela imagem.

Mudanças de ambiente, memória, CPU e segredos são feitas pelo próprio Terraform, sem script de sincronização. Confira o plano antes de aplicar. A troca da revisão do main interrompe temporariamente a interface.

Ao mudar `n8n_version`, aplique a configuração do CodeBuild mantendo a tag atual, execute o pipeline e registre a nova tag em `terraform.tfvars`. A versão é passada como build argument ao Dockerfile. Atualizações podem executar migrações de banco: faça backup e consulte as notas da versão. Rollback de imagem não desfaz migrações. Versões incompatíveis entre processos precisam de atualização coordenada com execuções interrompidas.

## Operação e segurança

As EC2 usam AMI ECS Optimized Amazon Linux 2023 ARM64, IMDSv2, EBS criptografado e Session Manager, sem SSH. Tasks recebem segredos pelo execution role; o task role não concede acesso AWS aos workflows. O ALB fica público. ALB → task usa HTTP privado; banco e fila usam TLS.

O Dockerfile obtém a cadeia pública de certificados do [trust store oficial do RDS](https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem) e a inclui em `/opt/certs/global-bundle.pem`, dentro da imagem. `DB_POSTGRESDB_SSL_CA_FILE` fornece essa cadeia diretamente à configuração PostgreSQL do n8n, permitindo validar o certificado do banco. A conexão continua com `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=true`.

Os certificados do host EC2 e do ambiente CodeBuild não são automaticamente compartilhados com o container. O arquivo é obtido durante o build, sem manutenção de uma cópia no repositório. Não contém chave privada e não substitui o certificado ACM usado no ALB. Para atualizar a cadeia, reconstrua a imagem sem reutilizar a camada em cache e faça uma nova entrega.

O laboratório usa o administrador gerenciado do RDS para simplificar a inicialização. Para uso permanente, prepare um usuário exclusivo com permissões para migrações. RDS administra a senha; tasks recebem o valor no início e precisam ser reiniciadas após rotação. Preserve a chave de criptografia de instalações existentes.

```bash
aws logs tail /ecs/aws-ecs-n8n/worker --follow
aws ecs describe-services \
  --cluster "$(terraform output -raw ecs_cluster_name)" \
  --services aws-ecs-n8n-main aws-ecs-n8n-webhook aws-ecs-n8n-worker
```

Logs mostram o processo e seus erros; o nível padrão não garante uma linha por execução. Consulte o histórico do n8n para os resultados. Container Insights está desabilitado.

Workflows que acessam portas externas além de HTTP/HTTPS precisam das regras de saída correspondentes. Arquivos persistentes exigem armazenamento compatível com queue mode e com a licença. O disco local das tasks não é persistência compartilhada. O workflow da demonstração será definido depois, na interface do n8n; o repositório contém apenas a infraestrutura.

## Validação local

```bash
terraform fmt -check -recursive
terraform validate
```

O uso da configuração correta e a revisão dos valores ficam com quem executa o laboratório; não há tipos, defaults ou validações em `variables.tf`.

## Retomar um apply interrompido

Um erro não desfaz os recursos já criados. Corrija a causa e gere outro plano antes de repetir o apply.

Se o ASG apresentar uma falha inicial de lançamento, confira suas atividades e as EC2: o grupo pode conseguir iniciá-las em uma tentativa automática posterior. Se as instâncias estiverem saudáveis e registradas no ECS, mas o plano indicar `aws_autoscaling_group.ecs is tainted`, remova somente essa marca do estado:

```bash
terraform untaint aws_autoscaling_group.ecs
terraform plan --var-file=live/sandbox/terraform.tfvars
```

O `untaint` não altera as instâncias. Use-o somente depois de confirmar que o recurso está funcionando. Confira que o novo plano não substitui o ASG antes de continuar com o apply.

## Remoção

`terraform destroy` também exclui a zona e os registros Route 53. Para manter o domínio no Route 53, preserve esses recursos antes de executar a remoção; não use o destroy completo abaixo diretamente.

Na limpeza de 21/10/2026, foram removidos os 100 recursos restantes, sem snapshot final do RDS e sem retenção dos dois segredos. A zona e todos os registros DNS foram preservados e continuam no estado do Terraform. O bucket compartilhado do backend também permanece. O registro da aplicação aponta para o ALB removido e será atualizado quando a infraestrutura for recriada.

Os comandos abaixo removem **todo o projeto, incluindo o Route 53**:

Pare novas entregas, espere os workflows terminarem e ajuste `main_count`, `webhook_count` e `worker_count` para zero. Atualize também `image_tag` com a versão em uso antes do apply. Se habilitou `deletion_protection`, desabilite e aplique antes da remoção.

```bash
terraform apply --var-file=live/sandbox/terraform.tfvars
terraform plan -destroy --var-file=live/sandbox/terraform.tfvars
terraform destroy --var-file=live/sandbox/terraform.tfvars
```

RDS deixa um snapshot final, que permanece na conta e pode consumir créditos. ECR e bucket de artefatos são esvaziados. Segredos ficam em recuperação por sete dias; recriar com o mesmo nome exige restaurar/importar ou esperar a exclusão. O bucket de estado permanece. Antes de excluir a hosted zone, volte a usar os servidores DNS do Registro.br, ou migre os registros para outro serviço DNS caso o domínio já esteja sendo usado.

## Referências

- [Queue mode n8n](https://docs.n8n.io/deploy/host-n8n/configure-n8n/scaling/enable-queue-mode.md)
- [Capacity Providers EC2](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/asg-capacity-providers.html)
- [Deploy ECS no CodePipeline](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-ECS.html)

## Licença

Distribuído sob a licença MIT. Consulte [LICENSE](LICENSE).
