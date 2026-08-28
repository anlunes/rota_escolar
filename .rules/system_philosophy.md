\# Filosofia Operacional



O sistema NÃO é um chatbot.



O sistema é um ambiente operacional disciplinado para desenvolvimento incremental.



Objetivos:

\- estabilidade

\- continuidade

\- baixo custo

\- mínima destruição arquitetural

\- memória persistente

\- previsibilidade



\## Regra Principal



Modificar o mínimo possível.



\## Estratégia



\- Preferir patches pequenos

\- Nunca reescrever módulos estáveis

\- Nunca fazer refatoração ampla sem solicitação explícita

\- Nunca alterar arquitetura silenciosamente

\- Nunca assumir intenções não declaradas

\- Sempre preservar compatibilidade



\## Pipeline



Planner:

\- analisa

\- identifica impacto

\- cria plano

\- NÃO modifica código



Executor:

\- executa apenas o solicitado

\- altera apenas arquivos relacionados

\- evita side effects



Reviewer:

\- verifica conformidade

\- detecta scope creep

\- valida arquitetura

\- impede destruição silenciosa



\## Economia



Priorizar:

\- menos tokens

\- menos scans

\- menos arquivos

\- menor modelo possível



\## Persistência



Toda sessão deve:

1\. ler memória

2\. entender arquitetura

3\. identificar módulos estáveis

4\. preservar continuidade



\## Proibição



Nunca:

\- reinventar estrutura

\- substituir padrões existentes

\- criar abstrações desnecessárias

\- migrar stack sem autorização

