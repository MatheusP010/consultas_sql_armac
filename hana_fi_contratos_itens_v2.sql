create materialized view fi_contratos_itens_v2 
as  WITH condicao as (
   SELECT 
        prcd_elements.knumv AS numero_condicao,
        prcd_elements.kposn AS item,
        SUM(CASE WHEN prcd_elements.kschl = 'ICMI' THEN prcd_elements.kwert END) AS Preco_Bruto,
        SUM(CASE WHEN prcd_elements.kschl = 'ZSEG' THEN prcd_elements.kwert END) AS Seguro,
        SUM(CASE WHEN prcd_elements.kschl = 'ZFRA' THEN prcd_elements.kwert END) AS Franquia,
        SUM(CASE WHEN prcd_elements.kschl = 'PR00' THEN prcd_elements.kwert END) AS Preco,
        SUM(CASE WHEN prcd_elements.kschl = 'ZEXC' THEN prcd_elements.kwert END) AS Horas_Exced,
        SUM(CASE WHEN prcd_elements.kschl = 'ZEXQ' THEN prcd_elements.kwert END) AS Qnt_H_Exc,
        SUM(CASE WHEN prcd_elements.kschl = 'ZEXQ' THEN prcd_elements.kwert END) AS Total_H_Exc,
        SUM(CASE WHEN prcd_elements.kschl = 'ZHVA' THEN prcd_elements.kwert END) AS Horas_Variaveis,
        SUM(CASE WHEN prcd_elements.kschl = 'ZHVQ' THEN prcd_elements.kwert END) AS Qnt_H_Var,
        SUM(CASE WHEN prcd_elements.kschl = 'ZHVQ' THEN prcd_elements.kwert END) AS Total_H_Var,
        SUM(CASE WHEN prcd_elements.kschl = 'ZFRE' THEN prcd_elements.kwert END) AS Frete,
        SUM(CASE WHEN prcd_elements.kschl = 'RB00' THEN prcd_elements.kwert END) AS Desconto
    FROM
        prcd_elements
    GROUP BY
        prcd_elements.knumv, prcd_elements.kposn
),
ultima_modificacao as (
    SELECT
        Id,
        usuario,
        ultima_modificacao
    FROM (
        SELECT
            LEFT(objectid, 10) as Id,
            username as usuario,
            CONCAT(udate, ' ', utime) AS ultima_modificacao,
            ROW_NUMBER() OVER(PARTITION BY LEFT(objectid, 10) ORDER BY CONCAT(udate, ' ', utime) DESC) as rn
        FROM
            cdhdr
    ) as subquery
    WHERE rn = 1
)

SELECT
    now() as "Data/hora Extração",
    ctr.vbeln AS "N. Contrato",
    vbak.ernam as "Criador",
    vbak.erdat AS "Data Criação",
    dtcbc.vinsdat as "Data Instalação",
    dtcbc.vuntdat AS "Data Assinatura",
    dtcbc.vbegdat AS "Início Contrato",
    dtcbc.venddat AS "Fim Contrato",
    dtcbc.vdemdat as "Data Desmontagem",
    vbkd.prsdt AS "Data Próximo Reajuste",
    ctr.kunnr_ana as "Cod. Cliente",
    CASE
        WHEN kna1.stcd1 = '' OR kna1.stcd1 IS NULL THEN kna1.stcd2
        ELSE kna1.stcd1
    END as "CNPJ_CPF",    
	TRIM(BOTH FROM concat(kna1.name1, ' ', kna1.name2, ' ', kna1.name3)) AS "Nome Cliente",
	vbkd.bstkd AS "Ref. Cliente",
	tvfst.vtext as "Bloq. Doc. Faturamento",
	RIGHT(dtcbc.vabndat,2) AS "Dia Fat.",
	dtitem.VBEGDAT as "Data Inicio Item",
	dtitem.VENDDAT as "Data Fim Item",
	dtitem.VDEMDAT as "Data Desmont. Item",
    ctr.matkl AS "Tipo Item",
    ctr.posnr AS "Item",
    ctr.zmeng as "Qtd. Prevista",
    case
		when ctr.arktx ~* 'avaria' then 'Avarias'
		when ctr.arktx ~* 'Prote|Seguro' then 'Seguro'
		when ctr.arktx ~* 'Frete|Mob' then 'Fretes'
		else zmtc.tipo_cobranca 
	end "Tipo Cobranca", 
    ctr.matnr AS "Material",
    ctr.arktx AS "Denominação do item",
    ctr.charg AS "N. Armac",
    case 
    	when ZSDT0001.flag_dev = 'X' then 'Devolvido'
        when ZSDT0001.flag_dev <> 'X' then 'Em Uso'
    	else 'Não Encontrado'
    end as "Status Ativo UCA",    
    tvagt.bezei as "Motivo de Recusa",
    CASE cpt.status_maq_cliente
            WHEN '1' THEN 'Ativo à Venda'
            WHEN '2' THEN 'Ativo Inativado'
            WHEN '3' THEN 'Auditoria UCA'
            WHEN '4' THEN 'Catalão - GO'
            WHEN '5' THEN 'Compras de Novos - Aguardando'    
            WHEN '6' THEN 'Em Clientes'
            WHEN '7' THEN 'Em Trânsito'
            WHEN '8' THEN 'Ouro Preto - MG'
            WHEN '9' THEN 'Paranaguá - PR'
            WHEN '10' THEN 'Reservado'
            WHEN '11' THEN 'Rio Grande do Sul - RS'
            WHEN '12' THEN 'Rondonópolis - MT'
            WHEN '13' THEN 'Serviço em Terceiros'            
            WHEN '14' THEN 'VGP 1 - SP'
            WHEN '15' THEN 'VGP 2 - SP'
            WHEN '16' THEN 'VGP 3 - SP'
            WHEN '17' THEN 'VGP 5 - SP'      
            WHEN '18' THEN 'Vila Velha - ES' 
        END AS "Status_Cocpit",
   	cond.preco_bruto AS "Preço Bruto",
    coalesce(cond.Franquia, 0) as "Franquia",
    coalesce(cond.Preco,0) as "Preco",
    coalesce(cond.Seguro, 0) as "Seguro",
    coalesce(cond.Horas_Exced, 0) as "Vlr. Hr Exced",
    coalesce(cond.Qnt_H_Exc, 0) as "Qtd. Hr Exced",
    coalesce(cond.Total_H_Exc, 0) as "R$ Total Hr Exced",
    coalesce(cond.Horas_Variaveis, 0) as "Vlr. Hr Variavel",
    coalesce(cond.Qnt_H_Var, 0) as "Qtd. Hr Variavel",
    coalesce(cond.Total_H_Var, 0)as "R$ Total Hr Variavel",
    coalesce(cond.Frete, 0) as "Frete",
    coalesce(cond.Desconto, 0) as "Desconto",
    CASE
        WHEN ctr.vbeln = ztcr.numero_contrato THEN ztcr.mercado_real
        WHEN ctr.auart_ana = 'ZVA' THEN 'SPOT - VAREJO'
        WHEN ctr.auart_ana = 'ZGC' THEN 'SPOT - GRANDES CONTAS'
        WHEN ctr.auart_ana = 'ZLP' THEN 'LONGO PRAZO'
        ELSE ''
    END AS "Tipo Contrato",
    CASE vbkd.kdgrp  
        WHEN 'ZA' THEN 'Biomassa'
        WHEN 'ZB' THEN 'Cidades Ferroviárias'
        WHEN 'ZC' THEN 'Consórcio'
        WHEN 'ZD' THEN 'Corporativo'
        WHEN 'ZE' THEN 'Empilhadeiras'
        WHEN 'ZF' THEN 'Florestal & Siderurgia'
        WHEN 'ZG' THEN 'Mineração'
        WHEN 'ZH' THEN 'Mix de Projetos'
        WHEN 'ZI' THEN 'Rental'
        WHEN 'ZJ' THEN 'Vale'
        WHEN 'ZK' THEN 'Yara / VLI / Mosaic'
         ELSE ''
    END AS "Vetor",
    kna1.ort01 AS "Cidade",
    kna1.regio AS "Estado",
    ctr.prctr AS "Centro de Lucro",
    t052u.text1 as "Cond. Pagamento",
    t042zt.text2 as "Forma de Pagamento",
    CASE
        WHEN CONCAT(rep_fat.name_org1, ' ', rep_fat.name_org2) = ' ' OR CONCAT(rep_fat.name_org1, ' ', rep_fat.name_org2) IS NULL THEN CONCAT(rep_fat.mc_name2, ' ', rep_fat.mc_name1)
        ELSE CONCAT(rep_fat.name_org1, ' ', rep_fat.name_org2)
    END AS "Representante Faturamento",
    CASE
        WHEN CONCAT(lead_fat.name_org1, ' ', lead_fat.name_org2) = ' ' OR CONCAT(lead_fat.name_org1, ' ', lead_fat.name_org2) IS NULL THEN CONCAT(lead_fat.name_first, ' ', lead_fat.name_last)
        ELSE CONCAT(lead_fat.name_org1, ' ', lead_fat.name_org2)
    END AS "Lider Faturamento",
    CASE
        WHEN CONCAT(vend.name_org1, ' ', vend.name_org2) = ' ' OR CONCAT(vend.name_org1, ' ', vend.name_org2) IS NULL THEN CONCAT(vend.name_first, ' ', vend.name_last)
        ELSE CONCAT(vend.name_org1, ' ', vend.name_org2)
    END AS "Vendedor",
    vbkd.kdkg1 as "Indice Reajuste 1",
    vbkd.kdkg2 as "Indice Reajuste 2",
    vbkd.kdkg3 as "Indice Reajuste 3",
    vbkd.kdkg4 as "Indice Reajuste 4",
    vbkd.kdkg5 as "Indice Reajuste 5",
    um.ultima_modificacao AS "Data_Hora Modificacao",
    um.usuario as "Usuário Modificacao"
    
FROM
    vbap AS ctr
    INNER join kna1 on ctr.kunnr_ana = kna1.kunnr
	inner join vbak on ctr.vbeln = vbak.vbeln and vbak.vbtyp = 'G' 
	INNER JOIN vbkd ON vbkd.vbeln = ctr.vbeln AND vbkd.posnr = '000000'
	LEFT join ZSDT0001 on ZSDT0001.vbeln = ctr.vbeln and ZSDT0001.posnr = ctr.posnr
	LEFT JOIN ultima_modificacao um ON ctr.vbeln = um.Id  
	left join veda dtcbc on ctr.vbeln = dtcbc.vbeln and dtcbc.vposn = '000000'
	left join veda dtitem on ctr.vbeln = dtitem.vbeln and ctr.posnr = dtitem.vposn
	left join fpla on ctr.fplnr_ana = fpla.fplnr
	left join tvfst on vbak.faksk = tvfst.faksp and tvfst.spras = 'P'
	left join tvagt on ctr.abgru = tvagt.abgru and tvagt.spras = 'P'
	left join t052u on vbkd.zterm = t052u.zterm and t052u.spras = 'P'
	left join t042zt on vbkd.zlsch = t042zt.zlsch and t042zt.spras = 'P'
	LEFT JOIN vbpa ON ctr.vbeln = vbpa.vbeln AND vbpa.parvw = 'ZF'
	LEFT JOIN but000 AS rep_fat ON vbpa.lifnr = rep_fat.partner
	LEFT JOIN vbpa AS lead ON ctr.vbeln = lead.vbeln AND lead.parvw = 'ES'
	LEFT JOIN but000 AS lead_fat ON lead.lifnr = lead_fat.partner
	LEFT JOIN vbpa AS vend_pa ON ctr.vbeln = vend_pa.vbeln AND vend_pa.parvw = 'ZV'
	LEFT JOIN but000 AS vend ON vend_pa.lifnr = vend.partner
	LEFT join condicao cond ON ctr.knumv_ana = cond.numero_condicao AND ctr.posnr = cond.item 
	LEFT JOIN ztfi_tp_ctr_real ztcr on ctr.vbeln = ztcr.numero_contrato
    left join ztfi_mat_tp_cobranca zmtc on ctr.matnr = zmtc.nr_material
    LEFT JOIN zsdt001 AS cpt ON cpt.vbeln = ctr.vbeln AND cpt.posnr = ctr.posnr
   
WHERE
    ctr.vbtyp_ana = 'G'

order by ctr.vbeln
