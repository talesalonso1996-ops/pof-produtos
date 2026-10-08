# ------------------------------------------------------------------
# R/gerar_ferramenta.R
# Le dados/produtos_pof.csv (gerado por R/calcular.R) e injeta os dados em
# ferramenta/template.html, gerando docs/index.html (a ferramenta).
# Uso: Rscript R/gerar_ferramenta.R
# ------------------------------------------------------------------
suppressMessages({ library(data.table); library(jsonlite) })
d <- fread("dados/produtos_pof.csv", sep = ";", encoding = "UTF-8", na.strings = c("", "NA"),
           colClasses = list(character = "cod_final"))
ED <- c("1987-1988", "1995-1996", "2002-2003", "2008-2009", "2017-2018")
REC <- c("Brasil", "Regiões metropolitanas")

prod <- unique(d[, .(cod = cod_final, produto, categoria, n1 = n1_num, subcategoria, qualidade, ausente = anos_ausentes)], by = "cod")
setorder(prod, cod)
# "ausente em" vem do status (o de-para marca 2017 para 24201, que recebe o quadro 44)
aus <- unique(d[status == "ausente", .(cod = cod_final, ano = substr(Edicao, 1, 4))])[order(ano), .(ausente = paste(ano, collapse = ", ")), by = cod]
prod[, ausente := NULL][aus, ausente := i.ausente, on = "cod"]
prod[, idx := .I - 1L]
d <- merge(d, prod[, .(cod_final = cod, idx)], by = "cod_final")
d[, ed := match(Edicao, ED) - 1L][, rec := match(Recorte, REC) - 1L]
stopifnot(!anyNA(d$ed), !anyNA(d$rec))

r <- function(x, k) ifelse(is.na(x), NA, round(x, k))
valores <- d[, .(idx, ed, rec, r(prevalencia, 2), r(prev_li, 2), r(prev_ls, 2), r(part_categoria, 3),
                 r(part_consumo, 4), r(part_consumo_li, 4), r(part_consumo_ls, 4), r(part_consumo_sem_aluguel, 4),
                 r(gasto_medio_2018, 2), match(status, c("ok", "ausente", "compartilhado", "sem_registro", "sem_compra")) - 1L,
                 ifelse(is.na(somado_em), "", somado_em))]
dados <- list(gerado = format(Sys.Date(), "%d/%m/%Y"),
              produtos = prod[, .(cod, produto, categoria, n1, subcategoria, qualidade, ausente)],
              valores = unname(lapply(seq_len(nrow(valores)), function(i) unname(as.list(valores[i])))))
json <- toJSON(dados, dataframe = "rows", na = "null", digits = NA, auto_unbox = TRUE)
tpl <- paste(readLines("ferramenta/template.html", encoding = "UTF-8", warn = FALSE), collapse = "\n")
out <- sub("/*DADOS*/", paste0("window.PRODUTOS = ", json, ";"), tpl, fixed = TRUE)
dir.create("docs", showWarnings = FALSE)
writeLines(enc2utf8(out), "docs/index.html", useBytes = TRUE)
cat("docs/index.html:", round(nchar(out, "bytes") / 1024), "KB |", nrow(prod), "produtos |", nrow(valores), "linhas\n")
