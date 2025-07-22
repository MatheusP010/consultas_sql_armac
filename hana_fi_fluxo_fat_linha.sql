WITH base AS (
    SELECT 
        "Data/hora Extração" - INTERVAL '3 HOURS' AS "Data_Hora Extração",
        "Codigo Cliente" as "Cod. Cliente",
        "Nome Cliente",
        "Ref. Cliente",
        "Tipo Contrato",
        "N. Contrato",
        "N. Ordem",
        "N. Fatura",
        "Status Ordem",
        "Dt. Faturamento",
        "Dt. Criacao Fat",
        "Mês Contabilidade",
        "Compet_Cabe_Ordem" AS "Compet. Medição",
        "Ini_Prog_Cabe" AS "Inicio Medição",
        "Fim_Prog_Cabe" AS "Fim Medição",
        "Compet_Linha" AS "Compet. Item",
        "Ini_Prog_Linha" AS "Inicio Item",
        "Fim_Prog_Linha" AS "Fim Item",
        
        -- Cálculo de Dias Utilização
        CASE 
            WHEN "Ini_Prog_Linha" IS NULL OR "Fim_Prog_Linha" IS NULL THEN 0
            ELSE DATE_PART('day', "Fim_Prog_Linha"::timestamp - "Ini_Prog_Linha"::timestamp) + 1
        END AS "Dias Utilização",

        -- Definição da frequência de cobrança
        CASE 
            WHEN "Tipo de Material" IN ('Máquina', 'Implementos', 'Seguro') THEN 'Recorrente'
            ELSE 'Única'
        END AS "Freq. Cobrança",

        -- Definição de Tipo Cobrança
        CASE 
            WHEN "Tipo de Material" NOT IN ('Máquina', 'Implementos', 'Seguro') THEN 'Integral'
            WHEN DATE_PART('day', "Fim_Prog_Linha"::timestamp - "Ini_Prog_Linha"::timestamp) + 1 >= 30 THEN 'Integral'
            WHEN DATE_PART('day', "Ini_Prog_Linha"::timestamp) <> DATE_PART('day', "Ini_Prog_Cabe"::timestamp) THEN 'Proporcional Mobilização'
            WHEN DATE_PART('day', "Fim_Prog_Linha"::timestamp) <> DATE_PART('day', "Fim_Prog_Cabe"::timestamp) THEN 'Proporcional Desmobilização'
            ELSE 'Integral'
        END AS "Tipo Cobrança",

        "Item Ctr",
        "Item Ord",
        "Tipo de Material",
        "Material" AS "N. Material",
        "Denominacao do item",
        "N. Armac",
        "Preco Bruto Contrato",        
        "Preco",
        "Total_H_Exc" AS "Horas Exc.",
        "Total_H_Var",
        "Total_H_Extra",
        "Frete",
        "Avaria",
        "Desconto",
        "Seguro",
        "Bloqueio",
        "Recusa",

        -- Verificação de Bloqueio Geral
        CASE 
            WHEN "Recusa" IS NULL AND "Bloqueio" IS NULL THEN 'Não'
            ELSE 'Sim'
        END AS "Bloq. Geral",

        -- Verificação Devolução
        CASE 
            WHEN "Doc. Contabil Dev." IS NULL THEN 'Não'
            ELSE 'Sim'
        END AS "Devolução",

        "Emissor Doc.",
        "Cond. Pagamento",
        "N. Doc Contabil",
        "Data Vencimento",
        "Centro",
        "Centro de Lucro",
        "Cidade",
        "Estado",
        "Repres. Faturam.",
        "Lider Faturam.",
        "Consultor Faturam.",
        "N. Doc. Dev.",
        "Data Emissao Doc. Dev.",
        "N. Fat. Dev.",
        "Data Criacao Fat. Dev.",
        "Data Faturamento Fat. Dev.",
        "Doc. Contabil Dev.",
        "Mes Contabil Dev.",
        "Emissor Dev.",
        "Prov Receita"
    
    FROM fi_fluxo_fat_linha
),

base_final AS (
    SELECT 
    	"Data_Hora Extração",
    	"Cod. Cliente",
        "Nome Cliente",
        "Ref. Cliente",
        "Tipo Contrato",
        "N. Contrato",
        "N. Ordem",
        "N. Fatura",
        "Status Ordem",
        "Dt. Faturamento",
        "Dt. Criacao Fat",
        "Mês Contabilidade",
        "Compet. Medição",
        "Inicio Medição",
        "Fim Medição",
        "Compet. Item",
        "Inicio Item",
        "Fim Item",
        "Dias Utilização",
	"Freq. Cobrança",
	"Tipo Cobrança",
        "Item Ctr",
        "Item Ord",
        "Tipo de Material",
        "N. Material",
        "Denominacao do item",
        "N. Armac",
        "Preco Bruto Contrato",
        
        -- Cálculo de Locação
        CASE 
            WHEN "Tipo de Material" IN ('Máquina', 'Implementos') 
                 AND "Status Ordem" = 'BM PENDENTE' 
                 AND "Tipo Cobrança" <> 'Integral' 
                 AND "Preco" > 0 
            THEN ("Preco" / 30) * "Dias Utilização"
            WHEN "Tipo de Material" IN ('Máquina', 'Implementos') 
                 AND "Status Ordem" = 'BM PENDENTE' 
                 AND "Tipo Cobrança" = 'Integral' 
                 AND "Preco" > 0
            THEN "Preco"
            WHEN "Tipo de Material" IN ('Máquina', 'Implementos') 
                 AND "Status Ordem" <> 'BM PENDENTE'  
                 AND "Preco" > 0 
            THEN "Preco"
            ELSE 0
        END AS "Locação",

        -- Cálculo de Seguro
		CASE 
    		WHEN "Tipo de Material" = 'Seguro' 
         		AND "Status Ordem" = 'BM PENDENTE' 
         		AND "Tipo Cobrança" <> 'Integral' 
         		AND "Seguro" >= 0  
    		THEN ("Preco" + "Seguro") / 30 * "Dias Utilização"
    		WHEN "Tipo de Material" = 'Seguro' 
         		AND "Seguro" >= 0  
    		THEN "Preco" + "Seguro"
    		WHEN "Seguro" >= 0
         		AND "Status Ordem" = 'BM PENDENTE' 
         		AND "Tipo Cobrança" <> 'Integral'   
    		THEN "Seguro" / 30 * "Dias Utilização"
    		WHEN "Seguro" >= 0  
    		THEN "Seguro"
    		ELSE 0
		END AS "Seguro",

        -- Cálculo de Frete
        CASE 
            WHEN "Tipo de Material" = 'Fretes' 
            THEN "Preco" + "Frete"
            WHEN "Frete" < 0 THEN 0
            ELSE "Frete"
        END AS "Frete",

        -- Cálculo de Avaria
        CASE 
            WHEN "Tipo de Material" = 'Avarias' AND "Avaria" = 0 AND "Preco" >= 0 THEN "Preco"
            WHEN "Avaria" < 0 THEN 0
            ELSE "Avaria"
        END AS "Avaria",
        
        "Horas Exc.",

		-- Cálculo de Desconto
		CASE 
    		WHEN "Preco" < 0 THEN ("Preco" + "Desconto")
    		WHEN "Frete" < 0 THEN ("Frete" + "Desconto")
    		WHEN "Seguro" < 0 THEN ("Seguro" + "Desconto")
    		WHEN "Desconto" < 0 THEN "Desconto"
    	ELSE 0
		END AS "Desconto",

        -- Cálculo de Outros
        CASE 
            WHEN "Tipo de Material" IN ('Outros', 'MO') AND "Preco" > 0 THEN "Preco"
            WHEN "Desconto" > 0 THEN "Desconto"
            WHEN "Total_H_Var" > 0 THEN "Total_H_Var"
            WHEN "Total_H_Extra" > 0 THEN "Total_H_Extra"
            ELSE 0
        END AS "Outros",
        "Bloq. Geral",
        "Emissor Doc.",
        "Cond. Pagamento",
        "N. Doc Contabil",
        "Data Vencimento",
        "Centro",
        "Centro de Lucro",
        "Cidade",
        "Estado",
        "Repres. Faturam.",
        "Lider Faturam.",
        "Consultor Faturam.",
        "Devolução",
        "N. Doc. Dev.",
        "Data Emissao Doc. Dev.",
        "N. Fat. Dev.",
        "Data Criacao Fat. Dev.",
        "Data Faturamento Fat. Dev.",
        "Doc. Contabil Dev.",
        "Mes Contabil Dev.",
        "Emissor Dev.",
        "Prov Receita"
    FROM base
)

SELECT * ,
    -- Cálculo de "Preço Final"
    CASE 
        WHEN "Bloq. Geral" = 'Sim' THEN 0
        ELSE 
            COALESCE("Locação", 0) + 
            COALESCE("Seguro", 0) + 
            COALESCE("Frete", 0) + 
            COALESCE("Avaria", 0) + 
            COALESCE("Horas Exc.", 0) + 
            COALESCE("Desconto", 0) + 
            COALESCE("Outros", 0)
    END AS "Preço Final"
FROM base_final
