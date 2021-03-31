/*
1. Crie uma SP para gerar um relatório contendo o nome e o somatório de vendas de um
   determinado produto por dia. O código do produto e a data devem ser os parâmetros
   de entrada.
*/

CREATE OR ALTER PROCEDURE VENDA_PRODUTO
    (P_PRODUTO INTEGER,
     P_DATA    TIMESTAMP)
RETURNS(
    NOME_PRODUTO VARCHAR(40),
    TOT_VENDAS NUMERIC(15,2)
    )
AS
BEGIN
   SELECT P.NOME, SUM(PV.QTD) QTDE
     FROM PRODUTO P
    INNER JOIN PRODUTOVENDIDO PV ON (PV.CODPROD = P.CODIGO)
    INNER JOIN VENDA V ON (V.NUMERO = PV.NUMERO)
    WHERE PV.CODPROD = :P_PRODUTO
      AND V.DATA     = :P_DATA
    GROUP BY P.NOME
    INTO :NOME_PRODUTO,
         :TOT_VENDAS;

   SUSPEND;
END;


/*
2) Crie uma SP que mostre a data e o somatório das vendas dos funcionários (estão
   cadastrados na tabela pessoa) que não possuem filhos (funcionários sem filhos →
   atributo filho IS NULL).
*/

CREATE OR ALTER PROCEDURE FUNC_VENDAS
RETURNS(
    NOME_FUN VARCHAR(40),
    DATA_VENDA TIMESTAMP,
    QTDE_VENDA NUMERIC(15,2),
    VALOR_VENDA NUMERIC(15,2)
)
AS
BEGIN
    SELECT P.NOME, V.DATA, SUM(PV.QTD) QTDE, SUM(PV.VALOR) VALOR
      FROM PESSOA P
           INNER JOIN VENDA V ON (V.CODFUN = P.CODIGO)
           INNER JOIN PRODUTOVENDIDO PV ON (PV.NUMERO = V.NUMERO)
     WHERE P.FILHO IS NULL
     GROUP BY P.NOME, V.DATA
      INTO :NOME_FUN,
           :DATA_VENDA,
           :QTDE_VENDA,
           :VALOR_VENDA;
    SUSPEND;
END;

/*
3. O Banco de Dados deve ter uma SP que efetue a atualização de salários dos
   funcionários. Todos os funcionários recebem 1.06% de aumento ao ano, a cada
   atualização do salário mínimo no mês de março. Além deste aumento, os funcionários
   que possuem filho têm um acréscimo de 0.5% em seu salário (acrescido sobre o salário
   atualizado) referente a despesas de creche. A SP gerenciar este cálculo para estes
   funcionário.
*/

CREATE OR ALTER PROCEDURE ATUALIZA_SALARIO
AS
   DECLARE VARIABLE COD_FUN INTEGER;
   DECLARE VARIABLE FUN_SALARIO NUMERIC(18,3);
   DECLARE VARIABLE FUN_FILHOS INTEGER;
   DECLARE VARIABLE NOVO_SALARIO NUMERIC(18,3);
BEGIN
    FOR SELECT P.CODIGO, P.SALARIO, P.FILHO
          FROM PESSOA P
         WHERE P.CODDEP IS NOT NULL
          INTO :COD_FUN,
               :FUN_SALARIO,
               :FUN_FILHOS
    DO
       NOVO_SALARIO = (:FUN_SALARIO*1.06);
       IF (:FUN_FILHOS > 0) THEN
       BEGIN
          NOVO_SALARIO = (:FUN_SALARIO*1.05);
       END

       UPDATE PESSOA P
          SET P.SALARIO = :NOVO_SALARIO
        WHERE P.CODIGO = :COD_FUN;
    SUSPEND;
END;


/*
4. Crie uma SP que atualize os preços de todos os produtos, de acordo com seu
   departamento. Passe o nome do departamento por parâmetro. Os ajustes são:
   1.5% para 'Vestuário'
   1.3% para 'Casa'
   0.7% para 'Informática'
   0.9% para 'Carro'
*/

CREATE OR ALTER PROCEDURE ATUALIZA_PRECO_PROD
AS
   DECLARE VARIABLE COD_PROD INTEGER;
   DECLARE VARIABLE PRECO_PROD NUMERIC(18,4);
   DECLARE VARIABLE NOME_DEPTO VARCHAR(40);
   DECLARE VARIABLE NOVO_PRECO NUMERIC(18,4);
BEGIN
   FOR SELECT P.CODIGO, P.PRECO, D.NOME
         FROM PRODUTO P
              INNER JOIN CATEGORIA C ON (C.CODIGO = P.CODCAT)
              INNER JOIN DEPARTAMENTO D ON (D.CODIGO = C.CODDEP)
         INTO :COD_PROD,
              :PRECO_PROD,
              :NOME_DEPTO
   DO
      IF (:NOME_DEPTO = 'Vestuário') THEN
      BEGIN
         NOVO_PRECO = (:PRECO_PROD * 1.015);
      END
      ELSE IF (:NOME_DEPTO = 'Casa') THEN
      BEGIN
         NOVO_PRECO = (:PRECO_PROD * 1.013);
      END
      ELSE IF (:NOME_DEPTO = 'Informática') THEN
      BEGIN
         NOVO_PRECO = (:PRECO_PROD * 1.007);
      END
      ELSE IF (:NOME_DEPTO = 'Carro') THEN
      BEGIN
         NOVO_PRECO = (:PRECO_PROD * 1.009);
      END

      IF (:NOVO_PRECO != :PRECO_PROD) THEN
      BEGIN
         UPDATE PRODUTO
            SET PRECO = :NOVO_PRECO
          WHERE CODIGO = :COD_PROD;
      END
END;


/*
5. O diretor geral solicitou ao DBA que crie no BD (que já existe) um controle de
   pontuação para os clientes. Este controle deve ser feito através de uma tabela chamada
   pontuação com os atributos 'codigo do cliente, data da compra e pontuação'.
   Inicialmente, a tabela deve ser criada e atualizada com os dados já constantes no BD.
   Para cada 10,00 em compra em uma data, o cliente recebe 2 pontos.
*/

CREATE TABLE PONTUACAO(
   COD_CLI INTEGER PRIMARY KEY,
   DATA_COMPRA TIMESTAMP NOT NULL,
   PONTUACAO INTEGER NOT NULL
)
CREATE UNIQUE INDEX PONTUACAO_IDX_CLI_DATA ON PONTUACAO (COD_CLI, DATA_COMPRA);

CREATE OR ALTER PROCEDURE ATUALIZA_PONTOS_CLIENTE
AS
   DECLARE VARIABLE DATA_VEN TIMESTAMP;
   DECLARE VARIABLE COD_CLIENTE INTEGER;
   DECLARE VARIABLE PONTOS_CLI INTEGER;
   DECLARE VARIABLE V_COUNT INTEGER;
BEGIN
   FOR SELECT V.DATA, V.CODCLIE, (TRUNC((SUM(PV.VALOR)/10))*2) AS PONTOS
         FROM VENDA V
              INNER JOIN PRODUTOVENDIDO PV ON (V.NUMERO = PV.NUMERO)
        GROUP BY V.DATA, V.CODCLIE
         INTO :DATA_VEN,
              :COD_CLIENTE,
              :PONTOS_CLI
   DO
      SELECT COUNT(P.COD_CLI)
        FROM PONTUACAO P
       WHERE P.COD_CLI = :COD_CLIENTE
         AND P.DATA_COMPRA = :DATA_VEN
        INTO :V_COUNT;
      IF (V_COUNT>0) THEN
      BEGIN
         UPDATE PONTUACAO P
            SET P.PONTUACAO = P.PONTUACAO + :PONTOS_CLI
          WHERE P.DATA_COMPRA = :DATA_VEN
            AND P.COD_CLI     = :COD_CLIENTE;
      END
      ELSE
      BEGIN
         INSERT INTO PONTUACAO (COD_CLI, PONTUACAO, DATA_COMPRA)
            VALUES (:COD_CLIENTE, :PONTOS_CLI, :DATA_VEN);
      END
END;