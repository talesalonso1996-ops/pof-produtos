# ------------------------------------------------------------------
# R/calcular.R
# Para cada produto (folha de consumo) da harmonizacao v2 de Arthur Welle,
# em cada edicao da POF e recorte, calcula:
#   - prevalencia: % das unidades de consumo (UCs) com gasto no produto
#   - % da categoria: participacao do produto no gasto do seu Nivel 1
#   - % do consumo: participacao na despesa de consumo (e sem aluguel)
#   - gasto medio mensal por UC, em reais de janeiro de 2018 (IPCA)
# Recortes: Brasil (2002 em diante) e conjunto das regioes metropolitanas
# (cinco edicoes). Intervalos de confianca de 95% do desenho amostral
# (2002 em diante) para prevalencia e % do consumo.
#
# Uso: Rscript R/calcular.R <pasta dos microdados HarmonizaPOF2026>
# Requer o pacote pofanalise (repositorio talesalonso1996-ops/pofanalise).
# ------------------------------------------------------------------
suppressMessages({ library(pofanalise); library(data.table); library(survey) })
options(survey.lonely.psu = "adjust")
args <- commandArgs(trailingOnly = TRUE)
dir_micro <- if (length(args)) args[1] else "c:/Users/Tales/Downloads/Pasta_Teste_VS/HarmonizaPOF2026_data"

log_msg <- function(...) { cat(format(Sys.time(), "%H:%M:%S"), ..., "
"); flush.console() }
h <- pof_harmonizacao()
fo <- h$folhas[n1_num <= 26]
fc <- fo$cod_final
cols <- paste0("f", fc)

estimar <- function(b, dom, rotulo) {
  sub <- b[dom]
  w <- sub$Peso
  cons <- sum(w * sub$Consumo)
  cons_sa <- sum(w * (sub$Consumo - sub$f17101))
  gasto <- vapply(cols, function(cl) sum(w * sub[[cl]]), 0)
  n1 <- as.integer(substr(fc, 1, 2))
  tot_n1 <- vapply(sprintf("n%02d", n1), function(cl) sum(w * sub[[cl]]), 0)
  res <- data.table(
    Edicao = sub$Edicao[1], Recorte = rotulo, cod_final = fc,
    prevalencia = vapply(cols, function(cl) 100 * sum(w * (sub[[cl]] > 0)) / sum(w), 0),
    ucs_com_gasto = vapply(cols, function(cl) sum(sub[[cl]] > 0), 0L),
    part_categoria = ifelse(tot_n1 > 0, 100 * gasto / tot_n1, NA_real_),
    part_consumo = 100 * gasto / cons,
    part_consumo_sem_aluguel = ifelse(fc == "17101", NA_real_, 100 * gasto / cons_sa),
    gasto_medio = gasto / sum(w),
    N_UC = nrow(sub))
  # intervalos de confianca (desenho montado na amostra inteira, dominio por
  # subset). As 280 variaveis indicadoras entram na base de uma vez, antes de
  # montar o desenho, para nao copiar a base a cada produto.
  if (all(c("UPA", "ESTRATO") %in% names(b))) {
    pcols <- paste0("p_", fc)
    for (k in seq_along(cols)) data.table::set(b, j = pcols[k], value = 100 * (b[[cols[k]]] > 0))
    des <- pof_desenho(b)
    d <- subset(des, dom)
    t0 <- Sys.time()
    ci_p <- suppressWarnings(stats::confint(survey::svymean(stats::reformulate(pcols), d)))
    ci_r <- suppressWarnings(stats::confint(survey::svyratio(stats::reformulate(cols), ~Consumo, d)))
    log_msg("   IC:", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s")
    b[, (pcols) := NULL]
    res[, `:=`(prev_li = ci_p[, 1], prev_ls = ci_p[, 2],
               part_consumo_li = 100 * ci_r[, 1], part_consumo_ls = 100 * ci_r[, 2])]
  } else {
    res[, `:=`(prev_li = NA_real_, prev_ls = NA_real_, part_consumo_li = NA_real_, part_consumo_ls = NA_real_)]
  }
  res
}

R <- list()
for (a in c(1987, 1995, 2002, 2008, 2017)) {
  cat("Edicao", a, "...\n")
  b <- pof_somar_grupos(pof_ler_edicao(a, dir_micro, h, folhas = fc))
  for (cl in setdiff(cols, names(b))) b[, (cl) := 0]
  if (a >= 2002) R[[length(R) + 1]] <- estimar(b, rep(TRUE, nrow(b)), "Brasil")
  R[[length(R) + 1]] <- estimar(b, !is.na(b$RGMT), "Regi\u00f5es metropolitanas")
  rm(b); invisible(gc())
}
d <- rbindlist(R, fill = TRUE)

# gasto medio em reais de janeiro de 2018 (POF 1987 esta em cruzados: NA)
fator <- c(`1987-1988` = NA, `1995-1996` = pof_deflacionar(1, "1995-1996"), `2002-2003` = pof_deflacionar(1, "2002-2003"),
           `2008-2009` = pof_deflacionar(1, "2008-2009"), `2017-2018` = 1)
d[, gasto_medio_2018 := gasto_medio * fator[Edicao]]
d[, gasto_medio := NULL]

meta <- fo[, .(cod_final, produto = nome, categoria = sub("^[0-9]+[.] ", "", n1), n1_num, subcategoria = sub("^[0-9.]+ ", "", n2),
               qualidade, anos_ausentes = if ("anos_ausentes" %in% names(fo)) anos_ausentes else NA_character_)]
d <- merge(meta, d, by = "cod_final")
setcolorder(d, c("Edicao", "Recorte", "cod_final", "produto", "categoria", "subcategoria", "qualidade"))
num <- c("prevalencia", "prev_li", "prev_ls", "part_categoria", "part_consumo", "part_consumo_li", "part_consumo_ls",
         "part_consumo_sem_aluguel", "gasto_medio_2018")
d[, (num) := lapply(.SD, function(x) round(x, 4)), .SDcols = num]
setorder(d, Recorte, Edicao, cod_final)
fwrite(d, "dados/produtos_pof.csv", sep = ";", bom = TRUE)

# checagens: participacoes na categoria somam 100 e no consumo somam ~100
chk <- d[, .(soma_cat = sum(part_categoria, na.rm = TRUE)), by = .(Edicao, Recorte, categoria)]
chk2 <- d[, .(soma_consumo = sum(part_consumo)), by = .(Edicao, Recorte)]
cat("\nSoma das participacoes na categoria: min", round(min(chk$soma_cat), 6), "max", round(max(chk$soma_cat), 6), "\n")
print(chk2)
cat("Linhas:", nrow(d), "| produtos:", uniqueN(d$cod_final), "\n")
