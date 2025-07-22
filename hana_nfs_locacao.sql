select 
	txt.bezei as tipo_nfs,
	ordc.vgbel as n_contrato,
	nfsi.aubel as n_ordem,
	nfsi.vbeln as n_fat,
	nfsc.xblnr as n_nfs,
	nfsc.fkdat as data_emissao,
	nfsi.posnr as n_item,
	nfsi.matnr as n_material,
	nfsi.arktx as descricao_item,
	nfsi.charg as n_armac,
	nfsi.netwr as valor_maq,
	nfsi.prctr as centro_lucro,
	case
		when nfsi.prctr = 'ARM3' then 'ARMAC - Dummy'
		else ncl.ktext
	end as nome_centro_lucro,
	CLI.KUNNR AS "Cód. Cliente",
 	CASE 
  		WHEN CLI.STCD1 = '' THEN CLI.STCD2
  		ELSE CLI.STCD1
 	END AS "CNPJ_CPF",
 	CONCAT(CLI.NAME1, ' ', CLI.NAME2, ' ', CLI.NAME3) AS "Nome do Cliente"
from vbrp nfsi
	left join kna1 cli on nfsi.kunrg_ana = cli.kunnr
	left join tvakt txt on nfsi.pstyv = txt.auart and txt.spras = 'P'
	left join vbrk nfsc on nfsi.vbeln = nfsc.vbeln
	left join vbak ordc on nfsi.aubel = ordc.vbeln
	left join cepct ncl on nfsi.prctr = ncl.prctr 
where 
	nfsi.pstyv IN ('ZSIM', 'ZDSR', 'ZROB', 'ZDNP', 'ZREB')
	and nfsi.draft = ''
	and nfsc.fkart not in ('S1', 'S2')
	and nfsc.fksto = ''
