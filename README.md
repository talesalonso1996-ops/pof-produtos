# Produtos da POF

Ferramenta interativa que mostra, para **cada produto da harmonização de Arthur Welle** (as 280 folhas de consumo da harmonização v2), em cada edição da Pesquisa de Orçamentos Familiares do IBGE (1987-1988 a 2017-2018):

- **Prevalência**: % das famílias (unidades de consumo) com gasto no produto;
- **% do gasto da categoria**: participação do produto no gasto do seu Nível 1 da harmonização;
- **% do gasto total**: participação na despesa de consumo, com ou sem o aluguel;
- **Gasto médio mensal por família**, em reais de janeiro de 2018 (IPCA).

Recortes: Brasil (2002-2003 em diante, com intervalos de confiança de 95% do desenho amostral) e conjunto das regiões metropolitanas (as cinco edições).

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `docs/index.html` | A ferramenta (abre direto no navegador, sem servidor) |
| `dados/produtos_pof.csv` | A tabela completa, uma linha por produto, edição e recorte (separador `;`) |
| `R/calcular.R` | Cálculo a partir dos microdados harmonizados, com o pacote [pofanalise](https://github.com/talesalonso1996-ops/pofanalise) |
| `R/gerar_ferramenta.R` | Gera `docs/index.html` a partir da tabela |
| `ferramenta/template.html` | Página da ferramenta, sem os dados |

## Reproduzir

```sh
Rscript R/calcular.R "pasta/dos/microdados/HarmonizaPOF2026"
Rscript R/gerar_ferramenta.R
```

## Colunas de `dados/produtos_pof.csv`

| Coluna | Descrição |
|---|---|
| `Edicao`, `Recorte` | Edição da POF e recorte (Brasil ou Regiões metropolitanas) |
| `cod_final`, `produto`, `categoria`, `subcategoria` | Folha, Nível 1 e Nível 2 da harmonização |
| `qualidade`, `anos_ausentes` | Nota de qualidade da folha e edições em que ela não aparece |
| `prevalencia`, `prev_li`, `prev_ls` | % das famílias com gasto e IC 95% |
| `ucs_com_gasto`, `N_UC` | Número de famílias na amostra com gasto e total no recorte |
| `part_categoria` | % do gasto do Nível 1 |
| `part_consumo`, `part_consumo_li`, `part_consumo_ls` | % da despesa de consumo e IC 95% |
| `part_consumo_sem_aluguel` | % da despesa de consumo sem aluguel (comparável com 1987 e 1995) |
| `gasto_medio_2018` | Gasto médio mensal por família (inclui quem não comprou), R$ de jan/2018 |

## Cuidados

- A prevalência depende do período de referência do questionário (7 dias para os alimentos da caderneta, 30 ou 90 dias para serviços, 12 meses para bens duráveis). Compare o mesmo produto entre edições ou recortes, não produtos de períodos diferentes.
- 1987-1988 e 1995-1996 só cobrem as regiões metropolitanas. Para comparar o % do gasto total com essas edições, use a versão sem aluguel.
- Folhas com qualidade média ou baixa podem estar ausentes em alguma edição; a ferramenta marca essas folhas. Ver a [validação com o IBGE](https://github.com/talesalonso1996-ops/pofanalise) no pacote pofanalise, que aponta itens trocados na harmonização em 2008-2009 e 2017-2018.

Ferramenta e cálculo: Tales Alonso. Harmonização dos produtos: Arthur Welle.
