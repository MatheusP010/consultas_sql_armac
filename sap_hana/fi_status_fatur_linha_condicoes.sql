-- public.fi_status_fatur_linha_condicoes fonte

CREATE OR REPLACE VIEW public.fi_status_fatur_linha_condicoes
AS WITH condicao AS (
         WITH selecao AS (
                 SELECT prcd_elements.knumv AS numero_condicao,
                    prcd_elements.kposn AS item,
                    prcd_elements.kschl,
                    prcd_elements.kwert,
                    prcd_elements.kbetr,
                    prcd_elements.zaehk,
                    prcd_elements.kinak
                   FROM prcd_elements
                  WHERE prcd_elements.kschl::text = ANY (ARRAY['PR00'::character varying, 'ICMI'::character varying, 'ZFRA'::character varying, 'ZEXC'::character varying, 'ZEXQ'::character varying, 'ZHVA'::character varying, 'ZHVQ'::character varying, 'ZHEX'::character varying, 'ZFRE'::character varying, 'RB00'::character varying, 'ZAVA'::character varying, 'ZSEG'::character varying]::text[])
                ), preco_mais_recente AS (
                 SELECT ranked.numero_condicao,
                    ranked.item,
                    ranked.zaehk AS ultimo,
                    ranked.kwert
                   FROM ( SELECT prcd.numero_condicao,
                            prcd.item,
                            prcd.zaehk,
                            prcd.kwert,
                            row_number() OVER (PARTITION BY prcd.numero_condicao, prcd.item ORDER BY prcd.zaehk DESC) AS rn
                           FROM selecao prcd
                          WHERE prcd.kschl::text = 'PR00'::text AND prcd.kinak::text <> 'X'::text) ranked
                  WHERE ranked.rn = 1
                )
         SELECT selecao.numero_condicao,
            selecao.item,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ICMI'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS preco_bruto,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZFRA'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS franquia,
            max(pmr.kwert) AS preco,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZEXC'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS horas_exced,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZEXQ'::text THEN selecao.kbetr
                    ELSE NULL::numeric
                END) AS qnt_h_exc,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZEXQ'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS total_h_exc,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZHVA'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS horas_variaveis,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZHVQ'::text THEN selecao.kbetr
                    ELSE NULL::numeric
                END) AS qnt_h_var,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZHVQ'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS total_h_var,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZHEX'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS total_h_extra,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZFRE'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS frete,
            max(
                CASE
                    WHEN selecao.kschl::text = 'RB00'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS desconto,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZAVA'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS avaria,
            max(
                CASE
                    WHEN selecao.kschl::text = 'ZSEG'::text THEN selecao.kwert
                    ELSE NULL::numeric
                END) AS seguro
           FROM selecao
             LEFT JOIN preco_mais_recente pmr ON selecao.numero_condicao::text = pmr.numero_condicao::text AND selecao.item::text = pmr.item::text
          GROUP BY selecao.numero_condicao, selecao.item
        ), rel_ord_ctr AS (
         SELECT DISTINCT ordens.vbeln AS n_ordens,
            ordens.vgbel AS "N. Contrato",
                CASE
                    WHEN ordens.vbeln::text ~~* '004%'::text THEN ordens.vbeln
                    ELSE ctr.vbeln
                END AS "N. Contrato2",
                CASE ctr.abstk
                    WHEN 'A'::text THEN 'PENDENTE'::character varying
                    WHEN 'B'::text THEN 'EM PROCESSAMENTO'::character varying
                    WHEN 'C'::text THEN 'CONCLUÍDO'::character varying
                    ELSE ctr.abstk
                END AS "Status",
            ctr.ernam AS "Criado por:",
                CASE
                    WHEN cprf."Tipo Contrato" = ''::text OR cprf."Tipo Contrato" IS NULL THEN cprf2."Tipo Contrato"
                    ELSE cprf."Tipo Contrato"
                END AS "Tipo Contrato",
            ordens.kunnr AS "Codigo Cliente",
                CASE
                    WHEN kna1.stcd1::text <> ''::text THEN kna1.stcd1
                    ELSE kna1.stcd2
                END AS "CNPJ/CPF",
            concat(kna1.name1, ' ', kna1.name2, ' ', kna1.name3) AS "Nome Cliente",
            vbkd.bstkd AS "Ref. Cliente",
            kna1.ort01 AS "Cidade",
            kna1.regio AS "Estado",
                CASE
                    WHEN cprf."Resp. Faturamento" IS NULL THEN cprf2."Resp. Faturamento"
                    ELSE cprf."Resp. Faturamento"
                END AS "Repres. Faturam.",
                CASE
                    WHEN cprf."Lider Faturam." IS NULL THEN cprf2."Lider Faturam."
                    ELSE cprf."Lider Faturam."
                END AS "Lider Faturam.",
                CASE
                    WHEN cprf."Consultor Faturam." IS NULL THEN cprf2."Consultor Faturam."
                    ELSE cprf."Consultor Faturam."
                END AS "Consultor Faturam."
           FROM vbak ordens
             LEFT JOIN vbak ctr ON ordens.vgbel::text = ctr.vbeln::text
             LEFT JOIN fi_contrato_por_repres_fatur cprf ON ordens.vbeln::text = cprf."N. Contrato"::text
             LEFT JOIN fi_contrato_por_repres_fatur cprf2 ON ordens.vgbel::text = cprf2."N. Contrato"::text
             LEFT JOIN kna1 ON ordens.kunnr::text = kna1.kunnr::text
             JOIN vbkd ON vbkd.vbeln::text = ordens.vbeln::text AND vbkd.posnr::text = '000000'::text
          WHERE ordens.vbtyp::text = ANY (ARRAY['C'::character varying, 'G'::character varying]::text[])
          ORDER BY ordens.vbeln
        ), material AS (
         SELECT zmtc.nr_material,
            zmtc.descr_grupo_material,
            zmtc.especif_tecnica,
            zmtc.tipo_cobranca
           FROM ztfi_mat_tp_cobranca zmtc
          WHERE zmtc.tipo_cobranca::text <> 'null'::text AND zmtc.descr_grupo_material::text <> 'PEÇAS'::text
        ), faturamento AS (
         SELECT DISTINCT row_number() OVER () AS "Linha Faturamento",
            vbrp.vgbel AS "N. Ordem",
            vbrp.vbeln AS "N. Fatura",
            vbrp.ernam AS "Emissor Fat.",
            vbap.vgbel AS "N. Contrato",
            bseg.belnr AS "N. Doc Contabil",
            to_date(bseg.fdtag::text, 'YYYY-MM-DD'::text) AS "Data Vencimento",
            to_date(vbrp.erdat::text, 'YYYY-MM-DD'::text) AS data_criacao_fat,
            to_date(vbrp.fkdat_ana::text, 'YYYY-MM-DD'::text) AS data_faturamento,
            vbrp.posnr AS "Item",
            vbfa.posnv AS item_vbfa_inicial,
            vbfa.posnn AS item_vbfa_fim,
            vbfa.ruuid AS item_vbfa_codigo,
            pbt_fat.preco_bruto AS preco_bruto_fat,
            to_char(date_trunc('month'::text, to_date(vbrp.fkdat_ana::text, 'YYYY-MM-DD'::text)::timestamp with time zone), 'YYYY-MM-DD'::text) AS "Contabilidade"
           FROM vbrp
             JOIN vbap ON vbap.vbeln::text = vbrp.aubel::text AND vbap.posnr::text = vbrp.aupos::text
             JOIN vbrk ON vbrk.vbeln::text = vbrp.vbeln::text AND (vbrk.fkart::text = ANY (ARRAY['ZSER'::character varying, 'ZLOC'::character varying, 'ZCTE'::character varying, 'ZSSM'::character varying, 'ZLSM'::character varying]::text[])) AND vbrk.fksto::text = ''::text
             LEFT JOIN vbfa ON vbfa.vbeln::text = vbrp.vbeln::text AND vbfa.posnn::text = vbrp.posnr::text AND vbfa.vbtyp_n::text = 'M'::text
             LEFT JOIN condicao pbt_fat ON vbrp.knumv_ana::text = pbt_fat.numero_condicao::text AND vbrp.posnr::text = pbt_fat.item::text
             LEFT JOIN bseg ON bseg.vbeln::text = vbrp.vbeln::text AND bseg.vorgn::text = 'SD00'::text AND bseg.buzei::text = '001'::text
          WHERE vbrp.draft::text = ''::text
        ), contratos_por_cabec AS (
         SELECT DISTINCT vbak.vbeln AS "N. Contrato",
            vbak.vgbel,
                CASE vbak.abstk
                    WHEN 'A'::text THEN 'PENDENTE'::character varying
                    WHEN 'B'::text THEN 'EM PROCESSAMENTO'::character varying
                    WHEN 'C'::text THEN 'CONCLUÍDO'::character varying
                    ELSE vbak.abstk
                END AS "Status",
            vbak.ernam AS "Criado por:",
            cond_pag.text1 AS "Cond. Pagamento",
            min(fplt.nfdat::date) AS "Ini_Medição_Cabeç",
            max(fplt.fkdat::date) AS "Fim_Medição_Cabeç",
            to_char(date_trunc('month'::text, to_date(fplt.fkdat::text, 'YYYY-MM-DD'::text)::timestamp with time zone), 'YYYY-MM-DD'::text) AS "Competencia_Cabeç",
            vbak.kunnr AS "Codigo Cliente"
           FROM vbak
             JOIN vbkd ON vbkd.vbeln::text = vbak.vbeln::text AND vbkd.posnr::text = '000000'::text
             LEFT JOIN fplt ON vbkd.fplnr::text = fplt.fplnr::text
             JOIN t052u cond_pag ON cond_pag.zterm::text = vbkd.zterm::text AND cond_pag.spras::text = 'P'::text
          WHERE (vbak.vbtyp::text = ANY (ARRAY['G'::character varying, 'C'::character varying]::text[])) AND (fplt.fkdat::text >= '2022-01-01'::text AND to_date(fplt.fkdat::text, 'YYYY-MM-DD'::text) < (date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) + '2 mons'::interval) OR fplt.fkdat IS NULL)
          GROUP BY vbak.vbeln, vbak.vgbel, vbak.abstk, vbak.ernam, cond_pag.text1, (to_char(date_trunc('month'::text, to_date(fplt.fkdat::text, 'YYYY-MM-DD'::text)::timestamp with time zone), 'YYYY-MM-DD'::text)), vbak.kunnr
        ), ordem_faturamento AS (
         SELECT DISTINCT fat."Linha Faturamento",
            roc."N. Contrato" AS "N. Contrato2",
            ordem.vgbel AS "N. Contrato3",
                CASE
                    WHEN ordem.vgbel IS NULL OR ordem.vgbel::text = ''::text THEN
                    CASE
                        WHEN fat."N. Contrato" IS NULL OR fat."N. Contrato"::text = ''::text THEN roc."N. Contrato"
                        ELSE fat."N. Contrato"
                    END
                    ELSE ordem.vgbel
                END AS "N. Contrato",
            ordem.vbeln AS "N. Ordem",
            vbak.ernam AS "Emissor Ord.",
            fat."Emissor Fat.",
            fat."N. Fatura",
                CASE ordem.fksaa
                    WHEN 'A'::text THEN 'FAT. PENDENTE'::text
                    WHEN 'B'::text THEN 'FATURADO'::text
                    WHEN 'C'::text THEN 'FATURADO'::text
                    WHEN NULL::text THEN 'FAT. PENDENTE'::text
                    ELSE 'FAT. PENDENTE'::text
                END AS "Status",
            fat.data_faturamento,
            fat."Data Vencimento",
            fat.data_criacao_fat,
            ordem.posnr AS item_ord,
            vbfa.posnv AS item_vbfa_inicio,
            vbfa.posnn AS item_vbfa_fim,
            fat."Item" AS item_fat,
            ordem.matkl AS "Tipo Item",
                CASE
                    WHEN ordem.arktx::text ~* 'avaria'::text THEN 'Avarias'::character varying
                    WHEN ordem.arktx::text ~* 'Prote|Seguro'::text THEN 'Seguro'::character varying
                    WHEN ordem.arktx::text ~* 'Frete|Mob'::text THEN 'Fretes'::character varying
                    ELSE mat.tipo_cobranca
                END AS "Tipo de Material",
            ordem.matnr AS "Material",
            ordem.arktx AS "Denominacao do item",
            ordem.charg AS "N. Armac",
            ordem.werks AS "Centro",
            ordem.prctr AS "Centro de Lucro",
            cpc."Ini_Medição_Cabeç" AS "Ini_Medicao_Cbç",
            cpc."Fim_Medição_Cabeç" AS "Fim_Medicao_Cbç",
            to_char(date_trunc('month'::text, to_date(cpc."Competencia_Cabeç", 'YYYY-MM-DD'::text)::timestamp with time zone), 'YYYY-MM-DD'::text) AS ord_competencia_cabe,
            to_char(date_trunc('month'::text, to_date(fplt.fkdat::text, 'YYYY-MM-DD'::text)::timestamp with time zone), 'YYYY-MM-DD'::text) AS ord_competencia_linha,
            to_date(fplt.nfdat::text, 'YYYY-MM-DD'::text) AS "Ini_Medicao_Linha",
            to_date(fplt.fkdat::text, 'YYYY-MM-DD'::text) AS "Fim_Medicao_Linha",
            pbt_ord.preco_bruto AS "Preco Bruto Ord",
            fat.preco_bruto_fat AS "Preco Bruto Fat",
            pbt_ord.franquia AS "Franquia_Ord",
            pbt_ord.preco AS "Preco_Ord",
            pbt_ord.horas_exced AS "Horas_Exced_Ord",
            pbt_ord.qnt_h_exc AS "Qnt_H_Exc_Ord",
            pbt_ord.total_h_exc AS "Total_H_Exc_Ord",
            pbt_ord.horas_variaveis AS "Horas_Variaveis_Ord",
            pbt_ord.qnt_h_var AS "Qnt_H_Var_Ord",
            pbt_ord.total_h_var AS "Total_H_Var_Ord",
            pbt_ord.total_h_extra AS "Total_H_Extra_Ord",
            pbt_ord.frete AS "Frete_Ord",
            pbt_ord.desconto AS "Desconto_Ord",
            pbt_ord.avaria AS "Avaria_Ord",
            pbt_ord.seguro AS "Seguro_Ord",
            fat."Contabilidade" AS "Mês Contabilidade",
            roc."Codigo Cliente",
            roc."Nome Cliente",
            roc."CNPJ/CPF",
            roc."Ref. Cliente",
                CASE
                    WHEN roc."Tipo Contrato" = ''::text OR roc."Tipo Contrato" IS NULL THEN
                    CASE
                        WHEN POSITION(('ARM3'::text) IN (ordem.prctr)) > 0 THEN 'ARM3'::text
                        WHEN "substring"(ordem.prctr::text, 4, 1) = '1'::text THEN 'LONGO PRAZO'::text
                        WHEN "substring"(ordem.prctr::text, 4, 1) = '2'::text THEN 'LONGO PRAZO'::text
                        WHEN "substring"(ordem.prctr::text, 4, 1) = '3'::text THEN 'SPOT - GRANDES CONTAS'::text
                        WHEN "substring"(ordem.prctr::text, 4, 1) = '4'::text THEN 'SPOT - VAREJO'::text
                        WHEN "substring"(ordem.prctr::text, 4, 1) = 'T'::text THEN 'SPOT - GRANDES CONTAS'::text
                        ELSE ''::text
                    END
                    ELSE roc."Tipo Contrato"
                END AS "Tipo Contrato",
            roc."Cidade",
            roc."Estado",
            roc."Repres. Faturam.",
            roc."Lider Faturam.",
            roc."Consultor Faturam.",
            fat."N. Doc Contabil",
            vbak.faksk AS "Bloqueio",
            ordem.abgru AS "Recusa",
            ztfi.prov_receita
           FROM vbap ordem
             JOIN vbak ON vbak.vbeln::text = ordem.vbeln::text
             LEFT JOIN faturamento fat ON ordem.vbeln::text = fat."N. Ordem"::text AND ordem.posnr::text = fat.item_vbfa_inicial::text
             FULL JOIN fplt ON ordem.fplnr_ana::text = fplt.fplnr::text
             LEFT JOIN condicao pbt_ord ON ordem.knumv_ana::text = pbt_ord.numero_condicao::text AND ordem.posnr::text = pbt_ord.item::text
             JOIN rel_ord_ctr roc ON ordem.vbeln::text = roc.n_ordens::text
             LEFT JOIN vbfa ON ordem.vbeln::text = vbfa.vbeln::text AND vbfa.posnn::text = ordem.posnr::text AND vbfa.vbtyp_v::text = 'G'::text
             LEFT JOIN ztfi_prov_receita ztfi ON ordem.vbeln::text = ztfi.ordem::text
             LEFT JOIN material mat ON mat.nr_material::text = ordem.matnr::text
             LEFT JOIN contratos_por_cabec cpc ON ordem.vbeln::text = cpc."N. Contrato"::text
          WHERE ordem.vbtyp_ana::text = 'C'::text AND (ordem.pstyv::text = ANY (ARRAY['ZSER'::character varying, 'ZLOC'::character varying, 'ZSSM'::character varying, 'ZCTE'::character varying]::text[]))
        ), contratos_por_linha AS (
         SELECT ctr.vbeln AS "N. Contrato",
                CASE vbak.abstk
                    WHEN 'A'::text THEN 'PENDENTE'::character varying
                    WHEN 'B'::text THEN 'EM PROCESSAMENTO'::character varying
                    WHEN 'C'::text THEN 'CONCLUÍDO'::character varying
                    ELSE vbak.abstk
                END AS "Status",
            min(to_date(fplt.nfdat::text, 'YYYY-MM-DD'::text)) AS "Ini_Medicao_Linha",
            max(to_date(fplt.fkdat::text, 'YYYY-MM-DD'::text)) AS "Fim_Medicao_Linha",
            to_char(date_trunc('month'::text, to_date(fplt.fkdat::text, 'YYYY-MM-DD'::text)::timestamp with time zone), 'YYYY-MM-DD'::text) AS "Competencia_Linha",
            ctr.matkl AS "Tipo Item",
            ctr.posnr AS "Item",
                CASE
                    WHEN ctr.arktx::text ~* 'avaria'::text THEN 'Avarias'::character varying
                    WHEN ctr.arktx::text ~* 'Prote|Seguro'::text THEN 'Seguro'::character varying
                    WHEN ctr.arktx::text ~* 'Frete|Mob'::text THEN 'Fretes'::character varying
                    ELSE mat.tipo_cobranca
                END AS "Tipo de Material",
            ctr.matnr AS "Material",
            ctr.arktx AS "Denominacao do item",
            ctr.charg AS "N. Armac",
            pbt_ctr.preco_bruto AS "Preco Bruto",
            pbt_ctr.franquia AS "Franquia_Ctr",
            pbt_ctr.preco AS "Preco_Ctr",
            pbt_ctr.horas_exced AS "Horas_Exced_Ctr",
            pbt_ctr.qnt_h_exc AS "Qnt_H_Exc_Ctr",
            pbt_ctr.total_h_exc AS "Total_H_Exc_Ctr",
            pbt_ctr.horas_variaveis AS "Horas_Variaveis_Ctr",
            pbt_ctr.qnt_h_var AS "Qnt_H_Var_Ctr",
            pbt_ctr.total_h_var AS "Total_H_Var_Ctr",
            pbt_ctr.total_h_extra AS "Total_H_Extra_Ctr",
            pbt_ctr.frete AS "Frete_Ctr",
            pbt_ctr.desconto AS "Desconto_Ctr",
            pbt_ctr.avaria AS "Avaria_Ctr",
            pbt_ctr.seguro AS "Seguro_Ctr",
            ctr.werks AS "Centro",
            ctr.prctr AS "Centro de Lucro",
            veda.vbegdat AS "Dt Inicio",
            veda.venddat AS "Dt Fim",
            roc."Codigo Cliente",
            roc."Nome Cliente",
            roc."CNPJ/CPF",
            roc."Ref. Cliente",
            roc."Cidade",
            roc."Estado",
            roc."Repres. Faturam.",
            roc."Lider Faturam.",
            roc."Consultor Faturam.",
                CASE
                    WHEN roc."Tipo Contrato" = ''::text OR roc."Tipo Contrato" IS NULL THEN
                    CASE vbak.auart
                        WHEN 'ZVA'::text THEN 'SPOT - VAREJO'::text
                        WHEN 'ZGC'::text THEN 'SPOT - GRANDES CONTAS'::text
                        WHEN 'ZLP'::text THEN 'LONGO PRAZO'::text
                        WHEN 'ZCS'::text THEN 'SPOT - CONSORCIO'::text
                        ELSE ''::text
                    END
                    ELSE roc."Tipo Contrato"
                END AS "Tipo Contrato",
            vbak.faksk AS "Bloqueio",
            ctr.abgru AS "Recusa"
           FROM vbap ctr
             JOIN vbak ON vbak.vbeln::text = ctr.vbeln::text
             JOIN fplt ON ctr.fplnr_ana::text = fplt.fplnr::text
             LEFT JOIN veda ON veda.vbeln::text = ctr.vbeln::text AND ctr.vbtyp_ana::text = 'G'::text AND veda.vposn::text = ctr.posnr::text
             LEFT JOIN rel_ord_ctr roc ON ctr.vbeln::text = roc.n_ordens::text
             LEFT JOIN material mat ON mat.nr_material::text = ctr.matnr::text
             LEFT JOIN condicao pbt_ctr ON ctr.knumv_ana::text = pbt_ctr.numero_condicao::text AND ctr.posnr::text = pbt_ctr.item::text
          WHERE ctr.vbtyp_ana::text = 'G'::text AND (fplt.fkdat::text >= '2022-11-01'::text AND fplt.fkdat::text <= '2022-12-21'::text AND ctr.vbeln::text = '0040000270'::text OR fplt.fkdat::text >= '2023-06-01'::text AND fplt.fkdat::text <= '2023-06-30'::text AND ctr.vbeln::text = '0040000413'::text OR fplt.fkdat::text >= '2023-12-01'::text AND fplt.fkdat::text <= '2023-12-31'::text AND ctr.vbeln::text = '0040001234'::text OR fplt.fkdat::text >= '2024-01-01'::text) AND to_date(fplt.fkdat::text, 'YYYY-MM-DD'::text) < (date_trunc('month'::text, CURRENT_DATE::timestamp with time zone) + '2 mons'::interval)
          GROUP BY ctr.vbeln, vbak.abstk, veda.vbegdat, veda.venddat, (to_char(date_trunc('month'::text, to_date(fplt.fkdat::text, 'YYYY-MM-DD'::text)::timestamp with time zone), 'YYYY-MM-DD'::text)), ctr.matkl, ctr.posnr, mat.tipo_cobranca, ctr.matnr, ctr.arktx, ctr.charg, ctr.netpr, ctr.werks, ctr.prctr, roc."Codigo Cliente", roc."Nome Cliente", roc."CNPJ/CPF", roc."Ref. Cliente", roc."Cidade", roc."Estado", roc."Repres. Faturam.", roc."Lider Faturam.", roc."Consultor Faturam.", roc."Tipo Contrato", vbak.faksk, vbak.auart, ctr.abgru, pbt_ctr.preco_bruto, pbt_ctr.franquia, pbt_ctr.preco, pbt_ctr.horas_exced, pbt_ctr.qnt_h_exc, pbt_ctr.total_h_exc, pbt_ctr.horas_variaveis, pbt_ctr.qnt_h_var, pbt_ctr.total_h_var, pbt_ctr.total_h_extra, pbt_ctr.frete, pbt_ctr.desconto, pbt_ctr.avaria, pbt_ctr.seguro
        ), status_cocpit_maquina AS (
         SELECT zsdt001.vbeln,
            zsdt001.posnr,
            zsdt001.status_maq_cliente
           FROM zsdt001
        ), devolucao AS (
         SELECT DISTINCT vbak.vgbel AS "N. Fat. Ord",
            vbak.vbeln AS "N. Doc. Dev.",
            to_date(vbak.erdat::text, 'YYYY-MM-DD'::text) AS "Data Emissao Doc. Dev.",
            vbrp.vbeln AS "N. Fat. Dev.",
            vbrp.ernam AS "Emissor Dev.",
            to_date(vbrk.erdat::text, 'YYYY-MM-DD'::text) AS "Data Criacao Fat. Dev.",
            to_date(vbrk.fkdat::text, 'YYYY-MM-DD'::text) AS "Data Faturamento Fat. Dev.",
            bseg.belnr AS "Doc. Contabil Dev.",
            to_char(to_date(vbrp.fkdat_ana::text, 'YYYY-MM-DD'::text)::timestamp with time zone, 'YYYY-MM-01'::text)::date AS "Mes Contabil Dev."
           FROM vbak
             LEFT JOIN vbrp ON vbak.vbeln::text = vbrp.aubel::text
             LEFT JOIN vbrk ON vbrk.vbeln::text = vbrp.vbeln::text
             LEFT JOIN bseg ON bseg.vbeln::text = vbrp.vbeln::text AND bseg.vorgn::text = 'SD00'::text
          WHERE vbak.vbtyp::text = 'H'::text AND vbrk.fksto::text = ''::text AND (vbrk.fkart::text <> ALL (ARRAY['S1'::character varying, 'S2'::character varying]::text[]))
        ), resultado1 AS (
         SELECT DISTINCT ordfat."Linha Faturamento",
            cpl."N. Contrato" AS "Contrato A",
            roc."N. Contrato" AS "Contrato B",
                CASE
                    WHEN cpl."N. Contrato" IS NULL THEN roc."N. Contrato"
                    ELSE cpl."N. Contrato"
                END AS "N. Contrato",
                CASE
                    WHEN cpl."Status" IS NULL THEN roc."Status"
                    ELSE cpl."Status"
                END AS "Status Contrato",
            ordfat."N. Ordem",
            ordfat."N. Fatura",
                CASE
                    WHEN cpc."Criado por:" IS NULL THEN roc."Criado por:"
                    ELSE cpc."Criado por:"
                END AS "Emissor Ctr.",
            ordfat."Emissor Ord.",
            ordfat."Emissor Fat.",
            cpc."Cond. Pagamento",
                CASE ordfat."Status"
                    WHEN 'FAT. PENDENTE'::text THEN 'FAT. PENDENTE'::text
                    WHEN 'FATURADO'::text THEN 'FATURADO'::text
                    WHEN NULL::text THEN 'BM PENDENTE'::text
                    ELSE 'BM PENDENTE'::text
                END AS "Status Ordem",
            ordfat.data_faturamento AS "Dt. Faturamento",
            ordfat."Mês Contabilidade",
            ordfat.data_criacao_fat AS "Dt. Criacao Fat",
            to_char(cpl."Ini_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) AS "Ini_Prog_Linha_Contrato",
            to_char(cpl."Fim_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) AS "Fim_Prog_Linha_Contrato",
            cpl."Competencia_Linha" AS "Compet_Linha_Contrato",
            to_char(cpc."Ini_Medição_Cabeç"::timestamp with time zone, 'YYYY-MM-DD'::text) AS "Ini_Prog_Cabe_Contrato",
            to_char(cpc."Fim_Medição_Cabeç"::timestamp with time zone, 'YYYY-MM-DD'::text) AS "Fim_Prog_Cabe_Contrato",
                CASE
                    WHEN cpc."Competencia_Cabeç" IS NOT NULL THEN cpc."Competencia_Cabeç"
                    ELSE ordfat.ord_competencia_cabe
                END AS "Compet_Cabe_Contrato",
            to_char(ordfat."Ini_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) AS "Ini_Prog_Linha_Ordem",
            to_char(ordfat."Fim_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) AS "Fim_Prog_Linha_Ordem",
            ordfat.ord_competencia_linha AS "Compet_Linha_Ordem",
            to_char(ordfat."Ini_Medicao_Cbç"::timestamp with time zone, 'YYYY-MM-DD'::text) AS "Ini_Prog_Cabe_Ordem",
            to_char(ordfat."Fim_Medicao_Cbç"::timestamp with time zone, 'YYYY-MM-DD'::text) AS "Fim_Prog_Cabe_Ordem",
            ordfat.ord_competencia_cabe AS "Compet_Cabe_Ordem",
                CASE
                    WHEN cpl."Tipo Item" IS NULL THEN ordfat."Tipo Item"
                    ELSE cpl."Tipo Item"
                END AS "Tipo Item",
                CASE
                    WHEN cpl."Item" IS NULL THEN ordfat.item_vbfa_inicio
                    ELSE cpl."Item"
                END AS "Item Ctr",
            cpl."Dt Inicio",
            cpl."Dt Fim",
            ordfat.item_ord AS "Item Ord",
                CASE
                    WHEN cpl."Tipo de Material" IS NULL AND ordfat."Tipo de Material" IS NULL THEN 'Indevido'::character varying
                    WHEN cpl."Tipo de Material" IS NOT NULL THEN cpl."Tipo de Material"
                    ELSE ordfat."Tipo de Material"
                END AS "Tipo de Material",
                CASE
                    WHEN cpl."Material" IS NULL THEN ordfat."Material"
                    ELSE cpl."Material"
                END AS "Material",
                CASE
                    WHEN cpl."Denominacao do item" IS NULL THEN ordfat."Denominacao do item"
                    ELSE cpl."Denominacao do item"
                END AS "Denominacao do item",
                CASE
                    WHEN cpl."N. Armac" IS NULL OR cpl."N. Armac"::text = ''::text THEN ordfat."N. Armac"
                    ELSE cpl."N. Armac"
                END AS "N. Armac",
                CASE
                    WHEN ordfat."Status" = 'FATURADO'::text THEN ordfat."Preco Bruto Fat"
                    ELSE ordfat."Preco Bruto Ord"
                END AS "Preco Bruto Ordem",
            cpl."Preco Bruto" AS "Preco Bruto Contrato",
            ordfat."Preco Bruto Fat",
            ordfat."Preco Bruto Ord" AS "Preco Bruto Ordem-Real",
                CASE
                    WHEN ordfat."Centro" IS NULL THEN cpl."Centro"
                    ELSE ordfat."Centro"
                END AS "Centro",
                CASE
                    WHEN ordfat."Centro de Lucro" IS NULL THEN cpl."Centro de Lucro"
                    ELSE ordfat."Centro de Lucro"
                END AS "Centro de Lucro",
                CASE
                    WHEN cpl."Codigo Cliente" IS NULL THEN ordfat."Codigo Cliente"
                    ELSE cpl."Codigo Cliente"
                END AS "Codigo Cliente",
                CASE
                    WHEN cpl."CNPJ/CPF" IS NULL THEN ordfat."CNPJ/CPF"
                    ELSE cpl."CNPJ/CPF"
                END AS "CNPJ/CPF",
                CASE
                    WHEN cpl."Nome Cliente" IS NULL THEN ordfat."Nome Cliente"
                    ELSE cpl."Nome Cliente"
                END AS "Nome Cliente",
                CASE
                    WHEN cpl."Ref. Cliente" IS NULL THEN ordfat."Ref. Cliente"
                    ELSE cpl."Ref. Cliente"
                END AS "Ref. Cliente",
                CASE
                    WHEN cpl."Repres. Faturam." IS NULL THEN ordfat."Repres. Faturam."
                    ELSE cpl."Repres. Faturam."
                END AS "Repres. Faturam.",
                CASE
                    WHEN cpl."Lider Faturam." IS NULL THEN ordfat."Lider Faturam."
                    ELSE cpl."Lider Faturam."
                END AS "Lider Faturam.",
                CASE
                    WHEN cpl."Consultor Faturam." IS NULL THEN ordfat."Consultor Faturam."
                    ELSE cpl."Consultor Faturam."
                END AS "Consultor Faturam.",
                CASE
                    WHEN cpl."Cidade" IS NULL THEN ordfat."Cidade"
                    ELSE cpl."Cidade"
                END AS "Cidade",
                CASE
                    WHEN cpl."Estado" IS NULL THEN ordfat."Estado"
                    ELSE cpl."Estado"
                END AS "Estado",
                CASE
                    WHEN cpl."Tipo Contrato" IS NULL THEN ordfat."Tipo Contrato"
                    ELSE cpl."Tipo Contrato"
                END AS "Tipo Contrato",
            ordfat."N. Doc Contabil",
            ordfat."Data Vencimento",
            cpl."Franquia_Ctr",
            cpl."Preco_Ctr",
            cpl."Horas_Exced_Ctr",
            cpl."Qnt_H_Exc_Ctr",
            cpl."Total_H_Exc_Ctr",
            cpl."Horas_Variaveis_Ctr",
            cpl."Qnt_H_Var_Ctr",
            cpl."Total_H_Var_Ctr",
            cpl."Total_H_Extra_Ctr",
            cpl."Frete_Ctr",
            cpl."Desconto_Ctr",
            cpl."Avaria_Ctr",
            cpl."Seguro_Ctr",
            ordfat."Franquia_Ord",
            ordfat."Preco_Ord",
            ordfat."Horas_Exced_Ord",
            ordfat."Qnt_H_Exc_Ord",
            ordfat."Total_H_Exc_Ord",
            ordfat."Horas_Variaveis_Ord",
            ordfat."Qnt_H_Var_Ord",
            ordfat."Total_H_Var_Ord",
            ordfat."Total_H_Extra_Ord",
            ordfat."Frete_Ord",
            ordfat."Desconto_Ord",
            ordfat."Avaria_Ord",
            ordfat."Seguro_Ord",
            bloqueio.vtext AS "Bloqueio CTR",
            recusa.bezei AS "Recusa CTR",
            bloqueio_ord.vtext AS "Bloqueio ORD",
            recusa_ord.bezei AS "Recusa ORD",
            devo."N. Doc. Dev.",
            devo."Data Emissao Doc. Dev.",
            devo."N. Fat. Dev.",
            devo."Emissor Dev.",
            devo."Data Criacao Fat. Dev.",
            devo."Data Faturamento Fat. Dev.",
            devo."Doc. Contabil Dev.",
            devo."Mes Contabil Dev.",
                CASE coc.status_maq_cliente
                    WHEN '1'::text THEN 'Ativo à Venda'::text
                    WHEN '2'::text THEN 'Ativo Inativado'::text
                    WHEN '3'::text THEN 'Auditoria UCA'::text
                    WHEN '4'::text THEN 'Catalão - GO'::text
                    WHEN '5'::text THEN 'Compras de Novos - Aguardando'::text
                    WHEN '6'::text THEN 'Em Clientes'::text
                    WHEN '7'::text THEN 'Em Trânsito'::text
                    WHEN '8'::text THEN 'Ouro Preto - MG'::text
                    WHEN '9'::text THEN 'Paranaguá - PR'::text
                    WHEN '10'::text THEN 'Reservado'::text
                    WHEN '11'::text THEN 'Rio Grande do Sul - RS'::text
                    WHEN '12'::text THEN 'Rondonópolis - MT'::text
                    WHEN '13'::text THEN 'Serviço em Terceiros'::text
                    WHEN '14'::text THEN 'VGP 1 - SP'::text
                    WHEN '15'::text THEN 'VGP 2 - SP'::text
                    WHEN '16'::text THEN 'VGP 3 - SP'::text
                    WHEN '17'::text THEN 'VGP 5 - SP'::text
                    WHEN '18'::text THEN 'Vila Velha - ES'::text
                    ELSE NULL::text
                END AS "Status_Cocpit",
            ordfat.prov_receita
           FROM contratos_por_linha cpl
             LEFT JOIN contratos_por_cabec cpc ON cpl."N. Contrato"::text = cpc."N. Contrato"::text AND cpl."Competencia_Linha"::date >= cpc."Ini_Medição_Cabeç" AND cpl."Competencia_Linha"::date <= cpc."Fim_Medição_Cabeç"
             FULL JOIN ordem_faturamento ordfat ON ordfat."N. Contrato"::text = cpl."N. Contrato"::text AND ordfat.item_vbfa_inicio::text = cpl."Item"::text AND (to_char(cpl."Fim_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) >= to_char(ordfat."Ini_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) AND to_char(cpl."Fim_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) <= to_char(ordfat."Fim_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) OR to_char(cpl."Fim_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) >= to_char(ordfat."Ini_Medicao_Cbç"::timestamp with time zone, 'YYYY-MM-DD'::text) AND to_char(cpl."Fim_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) <= to_char(ordfat."Fim_Medicao_Cbç"::timestamp with time zone, 'YYYY-MM-DD'::text) OR to_char(cpl."Ini_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) >= to_char(ordfat."Ini_Medicao_Cbç"::timestamp with time zone, 'YYYY-MM-DD'::text) AND to_char(cpl."Ini_Medicao_Linha"::timestamp with time zone, 'YYYY-MM-DD'::text) <= to_char(ordfat."Fim_Medicao_Cbç"::timestamp with time zone, 'YYYY-MM-DD'::text))
             LEFT JOIN rel_ord_ctr roc ON ordfat."N. Ordem"::text = roc.n_ordens::text
             LEFT JOIN status_cocpit_maquina coc ON coc.vbeln::text = cpl."N. Contrato"::text AND coc.posnr::text = cpl."Item"::text
             LEFT JOIN tvagt recusa ON recusa.abgru::text = cpl."Recusa"::text AND recusa.spras::text = 'P'::text
             LEFT JOIN tvfst bloqueio ON bloqueio.faksp::text = cpl."Bloqueio"::text AND bloqueio.spras::text = 'P'::text
             LEFT JOIN tvagt recusa_ord ON ordfat."Recusa"::text = recusa_ord.abgru::text AND recusa_ord.spras::text = 'P'::text
             LEFT JOIN tvfst bloqueio_ord ON ordfat."Bloqueio"::text = bloqueio_ord.faksp::text AND bloqueio_ord.spras::text = 'P'::text
             LEFT JOIN devolucao devo ON ordfat."N. Fatura"::text = devo."N. Fat. Ord"::text
        ), filtro AS (
         SELECT sub."Linha Faturamento",
            sub."Contrato A",
            sub."Contrato B",
            sub."N. Contrato",
            sub."Status Contrato",
            sub."N. Ordem",
            sub."N. Fatura",
            sub."Emissor Ctr.",
            sub."Emissor Ord.",
            sub."Emissor Fat.",
            sub."Cond. Pagamento",
            sub."Status Ordem",
            sub."Dt. Faturamento",
            sub."Mês Contabilidade",
            sub."Dt. Criacao Fat",
            sub."Ini_Prog_Linha_Contrato",
            sub."Fim_Prog_Linha_Contrato",
            sub."Compet_Linha_Contrato",
            sub."Ini_Prog_Cabe_Contrato",
            sub."Fim_Prog_Cabe_Contrato",
            sub."Compet_Cabe_Contrato",
            sub."Ini_Prog_Linha_Ordem",
            sub."Fim_Prog_Linha_Ordem",
            sub."Compet_Linha_Ordem",
            sub."Ini_Prog_Cabe_Ordem",
            sub."Fim_Prog_Cabe_Ordem",
            sub."Compet_Cabe_Ordem",
            sub."Tipo Item",
            sub."Item Ctr",
            sub."Dt Inicio",
            sub."Dt Fim",
            sub."Item Ord",
            sub."Tipo de Material",
            sub."Material",
            sub."Denominacao do item",
            sub."N. Armac",
            sub."Preco Bruto Ordem",
            sub."Preco Bruto Contrato",
            sub."Preco Bruto Fat",
            sub."Preco Bruto Ordem-Real",
            sub."Centro",
            sub."Centro de Lucro",
            sub."Codigo Cliente",
            sub."CNPJ/CPF",
            sub."Nome Cliente",
            sub."Ref. Cliente",
            sub."Repres. Faturam.",
            sub."Lider Faturam.",
            sub."Consultor Faturam.",
            sub."Cidade",
            sub."Estado",
            sub."Tipo Contrato",
            sub."N. Doc Contabil",
            sub."Data Vencimento",
            sub."Franquia_Ctr",
            sub."Preco_Ctr",
            sub."Horas_Exced_Ctr",
            sub."Qnt_H_Exc_Ctr",
            sub."Total_H_Exc_Ctr",
            sub."Horas_Variaveis_Ctr",
            sub."Qnt_H_Var_Ctr",
            sub."Total_H_Var_Ctr",
            sub."Total_H_Extra_Ctr",
            sub."Frete_Ctr",
            sub."Desconto_Ctr",
            sub."Avaria_Ctr",
            sub."Seguro_Ctr",
            sub."Franquia_Ord",
            sub."Preco_Ord",
            sub."Horas_Exced_Ord",
            sub."Qnt_H_Exc_Ord",
            sub."Total_H_Exc_Ord",
            sub."Horas_Variaveis_Ord",
            sub."Qnt_H_Var_Ord",
            sub."Total_H_Var_Ord",
            sub."Total_H_Extra_Ord",
            sub."Frete_Ord",
            sub."Desconto_Ord",
            sub."Avaria_Ord",
            sub."Seguro_Ord",
            sub."Bloqueio CTR",
            sub."Recusa CTR",
            sub."Bloqueio ORD",
            sub."Recusa ORD",
            sub."N. Doc. Dev.",
            sub."Data Emissao Doc. Dev.",
            sub."N. Fat. Dev.",
            sub."Emissor Dev.",
            sub."Data Criacao Fat. Dev.",
            sub."Data Faturamento Fat. Dev.",
            sub."Doc. Contabil Dev.",
            sub."Mes Contabil Dev.",
            sub."Status_Cocpit",
            sub.prov_receita,
            sub.row_num
           FROM ( SELECT t1."Linha Faturamento",
                    t1."Contrato A",
                    t1."Contrato B",
                    t1."N. Contrato",
                    t1."Status Contrato",
                    t1."N. Ordem",
                    t1."N. Fatura",
                    t1."Emissor Ctr.",
                    t1."Emissor Ord.",
                    t1."Emissor Fat.",
                    t1."Cond. Pagamento",
                    t1."Status Ordem",
                    t1."Dt. Faturamento",
                    t1."Mês Contabilidade",
                    t1."Dt. Criacao Fat",
                    t1."Ini_Prog_Linha_Contrato",
                    t1."Fim_Prog_Linha_Contrato",
                    t1."Compet_Linha_Contrato",
                    t1."Ini_Prog_Cabe_Contrato",
                    t1."Fim_Prog_Cabe_Contrato",
                    t1."Compet_Cabe_Contrato",
                    t1."Ini_Prog_Linha_Ordem",
                    t1."Fim_Prog_Linha_Ordem",
                    t1."Compet_Linha_Ordem",
                    t1."Ini_Prog_Cabe_Ordem",
                    t1."Fim_Prog_Cabe_Ordem",
                    t1."Compet_Cabe_Ordem",
                    t1."Tipo Item",
                    t1."Item Ctr",
                    t1."Dt Inicio",
                    t1."Dt Fim",
                    t1."Item Ord",
                    t1."Tipo de Material",
                    t1."Material",
                    t1."Denominacao do item",
                    t1."N. Armac",
                    t1."Preco Bruto Ordem",
                    t1."Preco Bruto Contrato",
                    t1."Preco Bruto Fat",
                    t1."Preco Bruto Ordem-Real",
                    t1."Centro",
                    t1."Centro de Lucro",
                    t1."Codigo Cliente",
                    t1."CNPJ/CPF",
                    t1."Nome Cliente",
                    t1."Ref. Cliente",
                    t1."Repres. Faturam.",
                    t1."Lider Faturam.",
                    t1."Consultor Faturam.",
                    t1."Cidade",
                    t1."Estado",
                    t1."Tipo Contrato",
                    t1."N. Doc Contabil",
                    t1."Data Vencimento",
                    t1."Franquia_Ctr",
                    t1."Preco_Ctr",
                    t1."Horas_Exced_Ctr",
                    t1."Qnt_H_Exc_Ctr",
                    t1."Total_H_Exc_Ctr",
                    t1."Horas_Variaveis_Ctr",
                    t1."Qnt_H_Var_Ctr",
                    t1."Total_H_Var_Ctr",
                    t1."Total_H_Extra_Ctr",
                    t1."Frete_Ctr",
                    t1."Desconto_Ctr",
                    t1."Avaria_Ctr",
                    t1."Seguro_Ctr",
                    t1."Franquia_Ord",
                    t1."Preco_Ord",
                    t1."Horas_Exced_Ord",
                    t1."Qnt_H_Exc_Ord",
                    t1."Total_H_Exc_Ord",
                    t1."Horas_Variaveis_Ord",
                    t1."Qnt_H_Var_Ord",
                    t1."Total_H_Var_Ord",
                    t1."Total_H_Extra_Ord",
                    t1."Frete_Ord",
                    t1."Desconto_Ord",
                    t1."Avaria_Ord",
                    t1."Seguro_Ord",
                    t1."Bloqueio CTR",
                    t1."Recusa CTR",
                    t1."Bloqueio ORD",
                    t1."Recusa ORD",
                    t1."N. Doc. Dev.",
                    t1."Data Emissao Doc. Dev.",
                    t1."N. Fat. Dev.",
                    t1."Emissor Dev.",
                    t1."Data Criacao Fat. Dev.",
                    t1."Data Faturamento Fat. Dev.",
                    t1."Doc. Contabil Dev.",
                    t1."Mes Contabil Dev.",
                    t1."Status_Cocpit",
                    t1.prov_receita,
                        CASE
                            WHEN t1."Linha Faturamento" IS NOT NULL THEN row_number() OVER (PARTITION BY t1."Linha Faturamento" ORDER BY t1."Linha Faturamento")
                            ELSE NULL::bigint
                        END AS row_num
                   FROM resultado1 t1) sub
          WHERE sub.row_num = 1 OR sub."Linha Faturamento" IS NULL
        ), final_query AS (
         SELECT filtro."Linha Faturamento",
            filtro."N. Contrato",
            filtro."Status Contrato",
            filtro."N. Ordem",
            filtro."N. Fatura",
            filtro."Status Ordem",
            filtro."Emissor Ctr.",
            filtro."Emissor Ord.",
            filtro."Emissor Fat.",
            filtro."Cond. Pagamento",
            filtro."Dt. Faturamento",
            filtro."Dt. Criacao Fat",
            filtro."Mês Contabilidade",
            min(filtro."Ini_Prog_Linha_Contrato") AS "Ini_Prog_Linha_Contrato",
            max(filtro."Fim_Prog_Linha_Contrato") AS "Fim_Prog_Linha_Contrato",
            filtro."Compet_Linha_Contrato",
            min(filtro."Ini_Prog_Cabe_Contrato") AS "Ini_Prog_Cabe_Contrato",
            max(filtro."Fim_Prog_Cabe_Contrato") AS "Fim_Prog_Cabe_Contrato",
            filtro."Compet_Cabe_Contrato",
            filtro."Ini_Prog_Linha_Ordem",
            filtro."Fim_Prog_Linha_Ordem",
            filtro."Compet_Linha_Ordem",
            filtro."Ini_Prog_Cabe_Ordem",
            filtro."Fim_Prog_Cabe_Ordem",
            filtro."Compet_Cabe_Ordem",
            filtro."Tipo Item",
            filtro."Item Ctr",
            filtro."Dt Inicio",
            filtro."Dt Fim",
            filtro."Item Ord",
            filtro."Tipo de Material",
            filtro."Material",
            filtro."Denominacao do item",
            filtro."N. Armac",
            COALESCE(max(filtro."Preco Bruto Contrato"), '0'::numeric) AS "Preco Bruto Contrato",
            COALESCE(max(filtro."Preco Bruto Ordem"), '0'::numeric) AS "Preco Bruto Ordem",
            filtro."Centro",
            filtro."Centro de Lucro",
            filtro."Codigo Cliente",
            filtro."CNPJ/CPF",
            filtro."Nome Cliente",
            filtro."Ref. Cliente",
            filtro."Repres. Faturam.",
            filtro."Lider Faturam.",
            filtro."Consultor Faturam.",
            filtro."Cidade",
            filtro."Estado",
            filtro."Tipo Contrato",
            filtro."N. Doc Contabil",
            filtro."Data Vencimento",
            COALESCE(filtro."Franquia_Ctr", '0'::numeric) AS "Franquia_Ctr",
            COALESCE(filtro."Preco_Ctr", '0'::numeric) AS "Preco_Ctr",
            COALESCE(filtro."Horas_Exced_Ctr", '0'::numeric) AS "Horas_Exced_Ctr",
            COALESCE(filtro."Qnt_H_Exc_Ctr", '0'::numeric) AS "Qnt_H_Exc_Ctr",
            COALESCE(filtro."Total_H_Exc_Ctr", '0'::numeric) AS "Total_H_Exc_Ctr",
            COALESCE(filtro."Horas_Variaveis_Ctr", '0'::numeric) AS "Horas_Variaveis_Ctr",
            COALESCE(filtro."Qnt_H_Var_Ctr", '0'::numeric) AS "Qnt_H_Var_Ctr",
            COALESCE(filtro."Total_H_Var_Ctr", '0'::numeric) AS "Total_H_Var_Ctr",
            COALESCE(filtro."Total_H_Extra_Ctr", '0'::numeric) AS "Total_H_Extra_Ctr",
            COALESCE(filtro."Frete_Ctr", '0'::numeric) AS "Frete_Ctr",
            COALESCE(filtro."Desconto_Ctr", '0'::numeric) AS "Desconto_Ctr",
            COALESCE(filtro."Avaria_Ctr", '0'::numeric) AS "Avaria_Ctr",
            COALESCE(filtro."Seguro_Ctr", '0'::numeric) AS "Seguro_Ctr",
            COALESCE(filtro."Franquia_Ord", '0'::numeric) AS "Franquia_Ord",
            COALESCE(filtro."Preco_Ord", '0'::numeric) AS "Preco_Ord",
            COALESCE(filtro."Horas_Exced_Ord", '0'::numeric) AS "Horas_Exced_Ord",
            COALESCE(filtro."Qnt_H_Exc_Ord", '0'::numeric) AS "Qnt_H_Exc_Ord",
            COALESCE(filtro."Total_H_Exc_Ord", '0'::numeric) AS "Total_H_Exc_Ord",
            COALESCE(filtro."Horas_Variaveis_Ord", '0'::numeric) AS "Horas_Variaveis_Ord",
            COALESCE(filtro."Qnt_H_Var_Ord", '0'::numeric) AS "Qnt_H_Var_Ord",
            COALESCE(filtro."Total_H_Var_Ord", '0'::numeric) AS "Total_H_Var_Ord",
            COALESCE(filtro."Total_H_Extra_Ord", '0'::numeric) AS "Total_H_Extra_Ord",
            COALESCE(filtro."Frete_Ord", '0'::numeric) AS "Frete_Ord",
            COALESCE(filtro."Desconto_Ord", '0'::numeric) AS "Desconto_Ord",
            COALESCE(filtro."Avaria_Ord", '0'::numeric) AS "Avaria_Ord",
            COALESCE(filtro."Seguro_Ord", '0'::numeric) AS "Seguro_Ord",
            filtro."Bloqueio CTR",
            filtro."Recusa CTR",
            filtro."Bloqueio ORD",
            filtro."Recusa ORD",
            filtro."N. Doc. Dev.",
            filtro."Emissor Dev.",
            filtro."Data Emissao Doc. Dev.",
            filtro."N. Fat. Dev.",
            filtro."Data Criacao Fat. Dev.",
            filtro."Data Faturamento Fat. Dev.",
            filtro."Doc. Contabil Dev.",
            filtro."Mes Contabil Dev.",
            filtro."Status_Cocpit",
            filtro.prov_receita
           FROM filtro
          GROUP BY filtro."Linha Faturamento", filtro."N. Contrato", filtro."Status Contrato", filtro."N. Ordem", filtro."N. Fatura", filtro."Status Ordem", filtro."Emissor Ctr.", filtro."Emissor Ord.", filtro."Emissor Fat.", filtro."Cond. Pagamento", filtro."Dt. Faturamento", filtro."Dt. Criacao Fat", filtro."Mês Contabilidade", filtro."Compet_Linha_Contrato", filtro."Compet_Cabe_Contrato", filtro."Ini_Prog_Linha_Ordem", filtro."Fim_Prog_Linha_Ordem", filtro."Compet_Linha_Ordem", filtro."Ini_Prog_Cabe_Ordem", filtro."Fim_Prog_Cabe_Ordem", filtro."Compet_Cabe_Ordem", filtro."Tipo Item", filtro."Item Ctr", filtro."Dt Inicio", filtro."Dt Fim", filtro."Item Ord", filtro."Tipo de Material", filtro."Material", filtro."Denominacao do item", filtro."N. Armac", filtro."Centro", filtro."Centro de Lucro", filtro."Codigo Cliente", filtro."CNPJ/CPF", filtro."Nome Cliente", filtro."Ref. Cliente", filtro."Repres. Faturam.", filtro."Lider Faturam.", filtro."Consultor Faturam.", filtro."Cidade", filtro."Estado", filtro."Tipo Contrato", filtro."N. Doc Contabil", filtro."Data Vencimento", filtro."Franquia_Ctr", filtro."Preco_Ctr", filtro."Horas_Exced_Ctr", filtro."Qnt_H_Exc_Ctr", filtro."Total_H_Exc_Ctr", filtro."Horas_Variaveis_Ctr", filtro."Qnt_H_Var_Ctr", filtro."Total_H_Var_Ctr", filtro."Total_H_Extra_Ctr", filtro."Frete_Ctr", filtro."Desconto_Ctr", filtro."Avaria_Ctr", filtro."Seguro_Ctr", filtro."Franquia_Ord", filtro."Preco_Ord", filtro."Horas_Exced_Ord", filtro."Qnt_H_Exc_Ord", filtro."Total_H_Exc_Ord", filtro."Horas_Variaveis_Ord", filtro."Qnt_H_Var_Ord", filtro."Total_H_Var_Ord", filtro."Total_H_Extra_Ord", filtro."Frete_Ord", filtro."Desconto_Ord", filtro."Avaria_Ord", filtro."Seguro_Ord", filtro."Bloqueio CTR", filtro."Recusa CTR", filtro."Bloqueio ORD", filtro."Recusa ORD", filtro."N. Doc. Dev.", filtro."Emissor Dev.", filtro."Data Emissao Doc. Dev.", filtro."N. Fat. Dev.", filtro."Data Criacao Fat. Dev.", filtro."Data Faturamento Fat. Dev.", filtro."Doc. Contabil Dev.", filtro."Mes Contabil Dev.", filtro."Status_Cocpit", filtro.prov_receita
        )
 SELECT final_query."Linha Faturamento",
    final_query."N. Contrato",
    final_query."Status Contrato",
    final_query."N. Ordem",
    final_query."N. Fatura",
    final_query."Status Ordem",
    final_query."Emissor Ctr.",
    final_query."Emissor Ord.",
    final_query."Emissor Fat.",
    final_query."Cond. Pagamento",
    final_query."Dt. Faturamento",
    final_query."Dt. Criacao Fat",
    final_query."Mês Contabilidade",
    final_query."Ini_Prog_Linha_Contrato",
    final_query."Fim_Prog_Linha_Contrato",
    final_query."Compet_Linha_Contrato",
    final_query."Ini_Prog_Cabe_Contrato",
    final_query."Fim_Prog_Cabe_Contrato",
    final_query."Compet_Cabe_Contrato",
    final_query."Ini_Prog_Linha_Ordem",
    final_query."Fim_Prog_Linha_Ordem",
    final_query."Compet_Linha_Ordem",
    final_query."Ini_Prog_Cabe_Ordem",
    final_query."Fim_Prog_Cabe_Ordem",
    final_query."Compet_Cabe_Ordem",
    final_query."Tipo Item",
    final_query."Item Ctr",
    final_query."Dt Inicio",
    final_query."Dt Fim",
    final_query."Item Ord",
    final_query."Tipo de Material",
    final_query."Material",
    final_query."Denominacao do item",
    final_query."N. Armac",
    final_query."Preco Bruto Contrato",
    final_query."Preco Bruto Ordem",
    final_query."Centro",
    final_query."Centro de Lucro",
    final_query."Codigo Cliente",
    final_query."CNPJ/CPF",
    final_query."Nome Cliente",
    final_query."Ref. Cliente",
    final_query."Repres. Faturam.",
    final_query."Lider Faturam.",
    final_query."Consultor Faturam.",
    final_query."Cidade",
    final_query."Estado",
    final_query."Tipo Contrato",
    final_query."N. Doc Contabil",
    final_query."Data Vencimento",
    final_query."Franquia_Ctr",
    final_query."Preco_Ctr",
    final_query."Horas_Exced_Ctr",
    final_query."Qnt_H_Exc_Ctr",
    final_query."Total_H_Exc_Ctr",
    final_query."Horas_Variaveis_Ctr",
    final_query."Qnt_H_Var_Ctr",
    final_query."Total_H_Var_Ctr",
    final_query."Total_H_Extra_Ctr",
    final_query."Frete_Ctr",
    final_query."Desconto_Ctr",
    final_query."Avaria_Ctr",
    final_query."Seguro_Ctr",
    final_query."Franquia_Ord",
    final_query."Preco_Ord",
    final_query."Horas_Exced_Ord",
    final_query."Qnt_H_Exc_Ord",
    final_query."Total_H_Exc_Ord",
    final_query."Horas_Variaveis_Ord",
    final_query."Qnt_H_Var_Ord",
    final_query."Total_H_Var_Ord",
    final_query."Total_H_Extra_Ord",
    final_query."Frete_Ord",
    final_query."Desconto_Ord",
    final_query."Avaria_Ord",
    final_query."Seguro_Ord",
    final_query."Bloqueio CTR",
    final_query."Recusa CTR",
    final_query."Bloqueio ORD",
    final_query."Recusa ORD",
    final_query."N. Doc. Dev.",
    final_query."Emissor Dev.",
    final_query."Data Emissao Doc. Dev.",
    final_query."N. Fat. Dev.",
    final_query."Data Criacao Fat. Dev.",
    final_query."Data Faturamento Fat. Dev.",
    final_query."Doc. Contabil Dev.",
    final_query."Mes Contabil Dev.",
    final_query."Status_Cocpit",
    final_query.prov_receita
   FROM final_query;
