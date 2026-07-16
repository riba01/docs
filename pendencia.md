Pronto. Consentimento presencial implementado, sem travar nenhum fluxo.

Classificação: Sensível em 1 ponto (classes/TermoConsentimento.php — alteração aditiva) + Média no restante.

Classes: TermoConsentimento (estendida), Connect, Auditoria, Crypto (indireto via guards).

Arquivos:

- classes/TermoConsentimento.php — 3 métodos novos: ensureColunasPresencial() (migra aceite_termo
  adicionando origem/coletado_por/data_coleta — automática, roda 1x), registrarAceitePresencial() (idempotente
  por rm+versão), statusAceite(). Métodos existentes intocados; gate do painel continua funcionando igual.
- Novo iecp/membro/ficha-Membro/registrarAceiteLgpd.php — endpoint AJAX: exige sessão + nível 2/3/4 + membro
  da mesma IECP do operador; valida data (não futura); grava aceite presencial com quem coletou; auditoria
  aceite_lgpd_presencial.
- iecp/membro/ficha-Membro/fichaMembro.php — aba nova LGPD: mostra status (aceite online / presencial /
  pendente); se pendente, campo de data + botão "Registrar aceite presencial". Também opção "Termo de
  Consentimento LGPD" no upload de documentos.
- Novo iecp/membro/termoLgpdPendentes.php — relatório da secretaria: badges coletados/pendentes/total,
  tabela de membros ativos sem aceite (exclui desligado/excluído/falecido/transferido), botão "Abrir ficha".
- menus/menu_iecp.php — item "Termos LGPD Pendentes" no submenu Membro.
- Mapas de tipo de documento atualizados: insereAnexo.php, meusDados.php, exportarRelatorioPdf.php.

Testes: php -l em todos os 8 arquivos; harness CLI validou: migração das colunas OK, 1º registro true, 2º
registro false (idempotente), aceite online existente preservado, query de pendentes retornou 92 membros na
IECP 1, rollback do dado de teste limpo.

Preservado: gate de aceite online no painel, tabela e registros existentes, fluxo de cadastro (nada
bloqueia), prepared statements, saída escapada.

Pendências: (1) ficha do CONIECP (fichaMinistro.php) sem a aba LGPD — replico se quiser; (2) nada commitado
ainda; (3) texto do termo impresso: usar a política de privacidade atual ou quer um termo próprio para
assinatura?
