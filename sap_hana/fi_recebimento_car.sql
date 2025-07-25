select
	bseg.kunnr as cod_cliente,
	CASE 
  		WHEN kna1.STCD1 = '' THEN kna1.STCD2
  		ELSE kna1.STCD1
 	END AS "CNPJ_CPF",
	TRIM(BOTH FROM CONCAT(kna1.name1, ' ', kna1.name2, ' ', kna1.name3)) AS nome_cliente,
	bseg.zuonr as referencia,
	bseg.belnr as lancamento_contabil,
	bseg.augbl as lancamento_compensacao,
	bseg.sgtxt as texto_item,
	bseg.dmbtr as montante_fatura,
	bseg.nebtr as valor_pago,
	bseg.h_blart as tipo_lancamento,
	bseg.augdt as Data_compensacao,
	bseg.h_budat as Data_receb_caixa
from bseg
	left join kna1 on bseg.kunnr = kna1.kunnr
where bseg.h_blart in ('DZ', 'ZB', 'ZR')
	and bseg.shkzg = 'H'
	and bseg.xragl <> 'X'
	and bseg.nebtr > 0
