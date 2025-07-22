--CREATE OR REPLACE VIEW fi_fat_seminovos AS
SELECT 
 CLI.KUNNR AS "Cód. Cliente",
 CASE 
  WHEN CLI.STCD1 = '' THEN CLI.STCD2
  ELSE CLI.STCD1
 END AS "CNPJ_CPF",
 CONCAT(CLI.NAME1, ' ', CLI.NAME2, ' ', CLI.NAME3) AS "Nome do Cliente",
 CASE
     WHEN VATI.PSTYV = 'ZVAT' THEN 'FATURADO'
     ELSE 'DEVOLVIDO'
 END AS "Status",
 VATI.AUBEL as "N.Ordem",
 VATI.VBELN AS "N. Fatura SAP",
 VATC.XBLNR AS "N. NF de Venda",
 BSEG.BELNR AS "N. Doc Contabil",
 TO_DATE(VATC.ERDAT, 'YYYY-MM-DD') AS "Data Criação",
 TO_DATE(VATC.FKDAT, 'YYYY-MM-DD') AS "Data Faturamento",
 TO_CHAR(TO_DATE(VATC.FKDAT, 'YYYY-MM-DD'), 'YYYY-MM-01') AS "Mês Contábil",
 VATI.POSNR AS "N. Item",
 VATI.MATNR AS "N. Material",
 VATI.ARKTX AS "Descrição do Material",
 VATI.CHARG AS "Lote",
 fag.chassi as "Chassi",
 fag.implemento,
 FAG.bu as "Classe",
 FAG.grupo as "Grupo",
 FAG.tipo as "Tipo",
 fag.marca as "Fabricante",
 fag.modelo as "Modelo",
 fag.ano_fabricacao,
 pdm.valor_doc_medicao as "Horimetro",
 CASE
     WHEN VATI.PSTYV = 'ZVAT' THEN VATI.KZWI1
     ELSE -VATI.KZWI1
 END AS "Valor Faturado",
 fag.valor_aquisicao as "Valor de Compra",
 fag.saldo_residual as "Saldo Residual",
 fag.valor_aquisicao_implemento as "Valor de Compra Implemento",
 fag.saldo_residual_implemento as "Saldo Residual Implemento",
 TXT.VTEXT as "Cond. Pagamento",
 VATI.WERKS AS "Centro",
 NCT.NAME1 AS "Nome Centro",
 VATI.PRCTR AS "Centro de Lucro",
 NCL.KTEXT AS "Nome Centro de Lucro"
FROM VBRP VATI
 LEFT JOIN KNA1 CLI ON VATI.KUNAG_ANA = CLI.KUNNR
 LEFT JOIN VBRK VATC ON VATI.VBELN = VATC.VBELN
 LEFT JOIN TVZBT TXT ON VATC.ZTERM = TXT.ZTERM and TXT.SPRAS = 'P'
 LEFT JOIN T001W NCT ON VATI.WERKS = NCT.WERKS
 LEFT JOIN CEPCT NCL ON VATI.PRCTR = NCL.PRCTR
 LEFT JOIN BSEG ON VATI.VBELN = BSEG.VBELN AND BSEG.VORGN = 'SD00'
 LEFT JOIN fi_ativos_geral fag ON vati.charg = fag.numero_armac
 LEFT JOIN pm_documentos_medicao pdm ON vati.charg = pdm.n_equipamento AND pdm.rank_doc_medicao = '1' AND descr_ponto_medicao = 'HORIMETRO ACUMULADO'
WHERE 
 VATI.PSTYV IN ('ZVAT', 'ZDAT', 'ZRAT') 
 AND VATI.DRAFT = ''
 AND VATC.FKART NOT IN ('S1', 'S2')
 AND VATC.FKSTO = ''
