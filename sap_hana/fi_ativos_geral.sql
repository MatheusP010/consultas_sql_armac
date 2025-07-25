--CREATE OR REPLACE VIEW fi_ativos_geral AS
WITH
-- Cálculo do saldo residual do ativo
calc AS (
    SELECT 
        TRIM(BOTH FROM anln1) AS anln1,
        SUM(kansw) + SUM(knafa) + SUM(nafag) + SUM(answl) AS saldo_residual
    FROM anlc
    WHERE afabe = '01' AND gjahr = TO_CHAR(CURRENT_DATE, 'YYYY')
    GROUP BY TRIM(BOTH FROM anln1)
),
-- Cálculo do saldo residual do implemento
calcim AS (
    SELECT 
        TRIM(BOTH FROM anln1) AS anln1,
        SUM(kansw) + SUM(knafa) + SUM(nafag) + SUM(answl) AS saldo_residual
    FROM anlc
    WHERE afabe = '01' AND gjahr = TO_CHAR(CURRENT_DATE, 'YYYY')
    GROUP BY TRIM(BOTH FROM anln1)
),
-- Status mais recente + dados do equipamento, sem duplicidade
status_unico AS (
    SELECT *
    FROM (
        SELECT 
            veq.equnr,
            veq.matnr,
            veq.baujj,
            veq.tplnr,
            veq.objnr,
            tj30t.txt30 AS status_equipamento,
            tj30t.txt04 AS cod_status,
            jcds.udate AS dt_modificacao,
            jcds.utime AS hr_modificacao,
            ROW_NUMBER() OVER (
                PARTITION BY TRIM(veq.equnr)
                ORDER BY jcds.udate DESC, jcds.utime DESC, veq.datbi DESC
            ) AS rn
        FROM v_equi veq
        LEFT JOIN jcds ON TRIM(veq.objnr) = TRIM(jcds.objnr)
        LEFT JOIN tj30t ON TRIM(jcds.stat) = TRIM(tj30t.estat)
        WHERE jcds.inact <> 'X'
          AND tj30t.spras = 'P'
          AND TRIM(tj30t.stsma) = 'ZPM_M_V'
    ) filtro
    WHERE rn = 1
)

-- Resultado final
SELECT DISTINCT
    TRIM(BOTH FROM anla.anln1) AS Numero_Armac,
  	CASE 
    	WHEN LEFT(TRIM(anla.anln1), 2) IN ('ID', 'IM', 'IR', 'VS') AND (anla.herst IS NULL OR TRIM(anla.herst) = '') 
    	THEN TRIM(anla.anln1)
        ELSE anla.herst
  	END AS Chassi,
    stt.matnr AS Material,
    bu.ordtx AS BU,
    gpo.ordtx AS Grupo,
    tpo.ordtx AS Tipo,
    mrc.ordtx AS Marca,
    anla.gdlgrp AS Modelo,
    stt.baujj AS Ano_Fabricacao,
    anla.txt50 AS Nome_Item,
    anla.invnr AS Implemento,
    anla.typbz AS nfe_compra,
    CASE
        WHEN anla.aktiv IS NULL OR anla.aktiv = '0000-00-00' THEN NULL
        ELSE TO_DATE(anla.aktiv, 'YYYY-MM-DD') 
    END AS Data_Compra,
    case
    	when left(anla.anln1, 2) = 'CM' or left(anla.invnr, 2) = 'CM' THEN (anla.urwrt + COALESCE(ainv.urwrt, 0))
    	else anla.urwrt
    end as valor,
    anla.urwrt AS Valor_Aquisicao,
    COALESCE(calc.saldo_residual, 0) AS Saldo_Residual,
    COALESCE(ainv.urwrt, 0) AS Valor_Aquisicao_Implemento,
    COALESCE(calcim.saldo_residual, 0) AS Saldo_Residual_Implemento,
    CASE 
    	WHEN anla.deakt IS NULL OR anla.deakt = '0000-00-00' THEN NULL
    	ELSE TO_DATE(anla.deakt, 'YYYY-MM-DD')
	END AS Data_Baixa,
    CASE 
        WHEN anla.deakt IS NOT NULL AND anla.deakt <> '0000-00-00' THEN 'Inativo'
        ELSE 'Ativo'
    END AS Status_Ativo,
    iflos.strno AS Local_Instalacao,
    stt.cod_status,
    stt.status_equipamento

FROM anla
LEFT JOIN calc ON TRIM(BOTH FROM anla.anln1) = calc.anln1
LEFT JOIN anla ainv ON TRIM(BOTH FROM anla.invnr) = TRIM(BOTH FROM ainv.anln1) AND ainv.anln2 = '0000'
LEFT JOIN calcim ON TRIM(BOTH FROM anla.invnr) = calcim.anln1
LEFT JOIN status_unico stt ON TRIM(BOTH FROM anla.anln1) = TRIM(BOTH FROM stt.equnr)
LEFT JOIN iflos ON TRIM(BOTH FROM stt.tplnr) = TRIM(BOTH FROM iflos.tplnr)
LEFT JOIN t087t bu  ON anla.ord41 = bu.ord4x
LEFT JOIN t087t gpo ON anla.ord42 = gpo.ord4x
LEFT JOIN t087t tpo ON anla.ord44 = tpo.ord4x
LEFT JOIN t087t mrc ON anla.ord43 = mrc.ord4x

WHERE anla.anln2 = '0000'
  AND LEFT(anla.anln1::text, 2) <> ALL (ARRAY['00', 'AD', 'AG', 'CB', 'EI', 'EL', 'FE', 'FO', 'GD', 'MP', 'MT', 'OP', 'ON', 'PÇ', 'TS', 'TN'])
