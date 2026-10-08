# ------------------------------------------------------------------
# R/status.R
# Classifica cada produto em cada edicao e ajusta a tabela:
#   ok            : produto com codigo proprio e registros nos microdados
#   ausente       : sem produtos no de-para nessa edicao (nao investigado)
#   compartilhado : o codigo original e' o mesmo de outra folha (ex.: peixe
#                   fresco e salgado); o gasto esta somado na outra folha e
#                   nao pode ser separado. Valores viram NA.
#   sem_registro  : o codigo do de-para nao tem nenhum registro nos
#                   microdados; o zero pode ser erro de codigo.
#   sem_compra    : codigo existe nos microdados, mas nenhuma familia da
#                   amostra comprou (zero legitimo, produto raro).
# Tambem limita os IC a [0, 100]. Roda ao final de R/calcular.R ou sozinho:
#   Rscript R/status.R <pasta dos microdados>
# ------------------------------------------------------------------
suppressMessages({ library(data.table); library(pofanalise) })
args <- commandArgs(trailingOnly = TRUE)
if (!exists("dir_micro")) dir_micro <- if (length(args)) args[1] else "c:/Users/Tales/Downloads/Pasta_Teste_VS/HarmonizaPOF2026_data"
h <- pof_harmonizacao()
prod <- fread(file.path(attr(h, "dir"), "produtos.csv"), encoding = "UTF-8", colClasses = list(character = c("cod_final", "codigo")))
prod[, codigo := as.integer(codigo)]
d <- fread("dados/produtos_pof.csv", sep = ";", encoding = "UTF-8", na.strings = c("", "NA"), colClasses = list(character = "cod_final"))
d[, intersect(c("status", "somado_em"), names(d)) := NULL]  # permite rodar de novo
d[, ano := as.integer(substr(Edicao, 1, 4))]

st <- rbindlist(lapply(c(1987, 1995, 2002, 2008, 2017), function(a) {
  micro <- unique(fread(file.path(dir_micro, pof_arquivos(a)$despesas), select = "Codigo")$Codigo)
  dp <- h$depara[ano == a]
  rbindlist(lapply(unique(d$cod_final), function(cf) {
    no_depara <- nrow(prod[ano == a & cod_final == cf]) > 0
    proprios <- dp[cod_final == cf]$codigo
    destino <- if (no_depara && !length(proprios)) paste(unique(dp[codigo %in% prod[ano == a & cod_final == cf]$codigo]$cod_final), collapse = ", ") else NA_character_
    data.table(ano = a, cod_final = cf,
      status = if (!no_depara) "ausente" else if (!length(proprios)) "compartilhado"
               else if (!any(proprios %in% micro)) "sem_registro" else "ok",
      somado_em = destino)
  }))
}))
d <- merge(d, st, by = c("ano", "cod_final"), all.x = TRUE)
# folha que recebe gasto por pof_correcoes() (ex.: aparelhos celulares do
# quadro 44 de 2017 em 24201) nao tem codigo proprio no de-para, mas tem dado
d[status %in% c("ausente", "compartilhado") & prevalencia > 0, `:=`(status = "ok", somado_em = NA)]
d[status == "ok" & prevalencia == 0, status := "sem_compra"]
med <- c("prevalencia", "prev_li", "prev_ls", "ucs_com_gasto", "part_categoria", "part_consumo", "part_consumo_li",
         "part_consumo_ls", "part_consumo_sem_aluguel", "gasto_medio_2018")
d[status %in% c("ausente", "compartilhado"), (med) := NA]
# IC limitados ao intervalo possivel
d[, `:=`(prev_li = pmax(prev_li, 0), prev_ls = pmin(prev_ls, 100), part_consumo_li = pmax(part_consumo_li, 0))]
d[, ano := NULL]
setcolorder(d, c("Edicao", "Recorte", "cod_final", "produto", "categoria", "subcategoria", "qualidade", "status", "somado_em"))
setorder(d, Recorte, Edicao, cod_final)
fwrite(d, "dados/produtos_pof.csv", sep = ";", bom = TRUE)
print(d[, .N, by = status])
