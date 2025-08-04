SELECT DISTINCT 
    *,
    CASE
        WHEN 
            "Tipo Cobranca" IN ('Máquina', 'Implementos', 'Seguro') AND
            "Data Fim Item" IS NOT NULL AND
            "Data Fim Item" > CURRENT_DATE AND
            "Data Inicio Item" IS NOT NULL AND
            "Data Inicio Item" <= CURRENT_DATE AND
            EXTRACT(YEAR FROM "Data Inicio Item") NOT IN (1900, 1990) AND
            "Bloq. Doc. Faturamento" IS NULL AND
            "Motivo de Recusa" IS NULL AND
            NOT ("Tipo Cobranca" = 'Máquina' AND ( "N. Armac" IS NULL OR TRIM("N. Armac") = ''))
        THEN 'Ativo'
        ELSE 'Inativo'
    END AS "Status_Item"
FROM 
    fi_contratos_itens_v2
WHERE 
    "Tipo Contrato" <> 'LONGO PRAZO'
