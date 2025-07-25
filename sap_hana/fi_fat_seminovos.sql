--CREATE OR REPLACE VIEW fi_fat_seminovos AS
WITH condicao AS (
    SELECT 
        pe.knumv AS numero_condicao,
        pe.kposn AS item,
        SUM(CASE WHEN pe.kschl = 'ZPRJ' THEN pe.kwert END) AS preco_c_juros,
        SUM(CASE WHEN pe.kschl = 'ZPRL' THEN pe.kwert END) AS preco_liquido
    FROM prcd_elements pe
    WHERE pe.kschl IN ('ZPRJ', 'ZPRL')
      AND EXISTS (
          SELECT 1
          FROM vbrp v
          JOIN vbrk k ON v.vbeln = k.vbeln
          WHERE v.knumv_ana = pe.knumv
            AND v.pstyv IN ('ZVAT', 'ZDAT', 'ZRAT')
            AND v.draft = ''
            AND k.fkart NOT IN ('S1', 'S2')
            AND k.fksto = ''
      )
    GROUP BY pe.knumv, pe.kposn
)
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
 TO_DATE(TO_CHAR(VATC.FKDAT, 'YYYY-MM-01'), 'YYYY-MM-DD') AS "Mês Contábil",
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
 coalesce(cond.preco_c_juros, 0) as "Preco c/ Juros",
 coalesce(cond.preco_liquido,0) as "Preco Liquido",
 fag.valor_aquisicao as "Valor de Compra",
 fag.saldo_residual as "Saldo Residual",
 fag.valor_aquisicao_implemento as "Valor de Compra Implemento",
 fag.saldo_residual_implemento as "Saldo Residual Implemento",
 TXT.VTEXT as "Cond. Pagamento",
 VATI.WERKS AS "Centro",
 NCT.NAME1 AS "Nome Centro",
 VATI.PRCTR AS "Centro de Lucro",
 NCL.KTEXT AS "Nome Centro de Lucro",
 CASE
        WHEN CONCAT(vend.name_org1, ' ', vend.name_org2) = ' ' OR CONCAT(vend.name_org1, ' ', vend.name_org2) IS NULL THEN CONCAT(vend.name_first, ' ', vend.name_last)
        ELSE CONCAT(vend.name_org1, ' ', vend.name_org2)
    END AS "Vendedor",
ref.bstkd as "Referencia"
FROM VBRP VATI
 LEFT JOIN KNA1 CLI ON VATI.KUNAG_ANA = CLI.KUNNR
 LEFT JOIN VBRK VATC ON VATI.VBELN = VATC.VBELN
 LEFT JOIN TVZBT TXT ON VATC.ZTERM = TXT.ZTERM and TXT.SPRAS = 'P'
 LEFT JOIN T001W NCT ON VATI.WERKS = NCT.WERKS
 LEFT JOIN CEPCT NCL ON VATI.PRCTR = NCL.PRCTR
 LEFT JOIN BSEG ON VATI.VBELN = BSEG.VBELN AND BSEG.VORGN = 'SD00' and bseg.buzei = '001'
 LEFT JOIN fi_ativos_geral fag ON vati.charg = fag.numero_armac
 LEFT JOIN pm_documentos_medicao pdm ON vati.charg = pdm.n_equipamento AND pdm.rank_doc_medicao = '1' AND descr_ponto_medicao = 'HORIMETRO ACUMULADO'
 left join condicao cond on vati.knumv_ana = cond.numero_condicao AND vati.posnr = cond.item
 LEFT JOIN vbpa AS vend_pa ON vati.aubel = vend_pa.vbeln and vati.posnr = vend_pa.posnr and vend_pa.parvw = 'ZV'
 LEFT JOIN but000 AS vend ON vend_pa.lifnr = vend.partner
 LEFT JOIN vbkd ref on vati.aubel = ref.vbeln and ref.posnr = '000000'
WHERE 
 VATI.PSTYV IN ('ZVAT', 'ZDAT', 'ZRAT') 
 AND VATI.DRAFT = ''
 AND VATC.FKART NOT IN ('S1', 'S2')
 AND VATC.FKSTO = ''
