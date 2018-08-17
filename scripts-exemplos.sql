psql -> \timing

--Ambiente
CREATE TEMP TABLE cars (name varchar PRIMARY KEY, price_range int4range);
insert into cars values ('Buick Skylark', int4range(2000,4001));
insert into cars values ('Chevrolet Camero', int4range(10000,12001));
insert into cars values ('Pontiac GTO', int4range(5000,7501));
insert into cars values ('Ford Mustang', int4range(11000,15001));
insert into cars values ('Lincoln Continental', int4range(12000,14001));
insert into cars values ('BMW M3', int4range(35000,42001));
insert into cars values ('Audi RS4', int4range(41000,45001));
insert into cars values ('Porsche 911', int4range(47000,58001));
insert into cars values ('Lamborghini LP700', int4range(385000,400001));

CREATE TEMP TABLE paginas (
	dominio text not null, -- [Sub]domínio
	url text not null,     -- URL, dentro do [sub]domínio
	acessos integer,       -- quantidade de acessos
	tags text[],           -- array de tags
	CONSTRAINT pk_paginas PRIMARY KEY (dominio, url)
);

INSERT INTO paginas(dominio,url,acessos,tags)
VALUES
	('www.example.com', '/index.html',	448, '{index,exemplo}'),
	('www.example.com', '/contato.html',      201, '{contato}'),
	('www.example.com', '/exemplo.html',      272, '{exemplo,teste}'),
	('blog.example.com', '/index.html',       513, '{blog}'),
	('blog.example.com', '/postgresql.html',  896, '{blog,postgresql}'),
	('blog.example.com', '/postgres-xc.html', 1036, '{postgresql,escalabilidade}'),
	('evento.example.com', '/',                640, '{evento,postgresql}'),
	('evento.example.com', '/inscricao.html',  289, '{evento,inscrição}');

CREATE TEMP TABLE serie
	AS SELECT generate_series(1,20) AS val;

create temp table historico_vendas(quantidade int,produto int );
insert into historico_vendas values (10,1), (20,2), (30,2), (15,3);

create temp table palavras (sequencia varchar);
insert into palavras values ('ab,cd,ef'), ('gh,ij,kl');


--Visões materializadas
	gestao.view_gra_carga_horaria_integralizada_tmp
	gestao.view_gra_carga_horaria_integralizada

EXPLAIN ANALYZE select * FROM gestao.view_gra_carga_horaria_integralizada_tmp;
EXPLAIN ANALYZE select * FROM gestao.view_gra_carga_horaria_integralizada;

-----------------------------
--Range

select int4range(1,5);
select int4range(1,5) @> 3;
select int4range(1,5) @> 6;
select int4range(1,5) && int4range(3,7);
select int4range(1,5) && int4range(6,7);

select int4range(1,5) @> 1;
select int4range(1,5) @> 5;

select int4range(1,5, '[]') @> 5;

select int4range(3,null) @> 42;

--Exemplo preços de carros
SELECT * FROM cars;
--drop table cars;

--Preços com valores na faixa de 13.000 - 15.000

-- Select utilizando colunas para valor mínimo e máximo
SELECT * FROM cars
	WHERE
	(
		cars.min_price <= 13000 AND
		cars.min_price <= 15000 AND
		cars.max_price >= 13000 AND
		cars.max_price <= 15000
	) OR
					(
		cars.min_price <= 13000 AND
		cars.min_price <= 15000 AND
		cars.max_price >= 13000 AND
		cars.max_price >= 15000
	) OR
					(
		cars.min_price >= 13000 AND
		cars.min_price <= 15000 AND
		cars.max_price >= 13000 AND
		cars.max_price <= 15000
	) OR
					(
		cars.min_price >= 13000 AND
		cars.min_price <= 15000 AND
		cars.max_price >= 13000 AND
		cars.max_price >= 15000
	)
	ORDER BY cars.min_price;


--SELECT utilizando intervalos
SELECT * FROM cars
	WHERE cars.price_range && int4range(13000, 15000, '[]')
		ORDER BY lower(cars.price_range);

--Carros com o preço não ultrapasse 13.000
SELECT * FROM cars
	WHERE cars.price_range << int4range(13000, 15000)
		ORDER BY lower(cars.price_range);

--Carros com preço acimad de 15.000
SELECT * FROM cars
	WHERE cars.price_range >> int4range(13000, 15000)
		ORDER BY lower(cars.price_range);

--Carros com preço no máximo até 15.000
SELECT * FROM cars
	WHERE cars.price_range &< int4range(13000, 15000)
	ORDER BY lower(cars.price_range);

-----------------------------
--UPSERT — "UPDATE or INSERT"

WITH cte (valor) AS (
	SELECT 1
	UNION
	SELECT 2
	UNION
	SELECT 3
)
SELECT * FROM cte WHERE valor >= 2;


SELECT * FROM cars ORDER BY lower(cars.price_range);


INSERT INTO cars (name, price_range)
	VALUES ('Corolla', '[58000,62000]')
	ON CONFLICT (name)
	DO
	  UPDATE SET (price_range) = ('[70000,83000]')
			where cars.name = 'Corolla';

SELECT * FROM cars ORDER BY lower(cars.price_range);


delete from cars where name ilike 'Corolla%';
with upsert as (
	update cars
		set (price_range) = ('[70000,83000]')
		where cars.name = 'Corolla'
	        returning *
	)
	INSERT INTO cars (name, price_range)
		SELECT 'Corolla', '[58000,62000]'
			where not exists (
				select 1
					from upsert
					where upsert.name = 'Corolla'

		);

-----------------------------
--Window Function
select * from paginas;

--Média de acesso por domínio
SELECT dominio, AVG(acessos) AS media_acessos
	FROM paginas GROUP BY dominio ORDER BY 2;


--Verificar, com uma única consulta, a comparação de acessos de cada URL com a média
--de acesso do domínio
SELECT dominio, url, AVG(acessos) OVER(PARTITION BY dominio) AS media_acessos
	FROM paginas;


--Usando janela com o ORDER BY - soma parcial dos acessos
SELECT dominio, url, acessos,
	SUM(acessos) OVER(ORDER BY acessos, dominio, url) AS parcial
		FROM paginas
ORDER BY acessos, dominio, url;

--Soma parcial e a média, ambas agrupados por domínio
SELECT dominio, url, acessos,
	AVG(acessos) OVER(PARTITION BY dominio) AS media_acessos,
	SUM(acessos) OVER(PARTITION BY dominio ORDER BY acessos, url) AS parcial
FROM paginas
ORDER BY dominio, acessos, url;

-----------------------------
--SQL WITHIN GROUP

--Calcular o 25º percentil, 50º percentil, o 75º percentil e o 100º percentil dos primeiros 20 inteiros.
SELECT * FROM serie;

--Teria que ser feito da seguinte forma:
WITH subset AS (
    SELECT
       ntile(4) OVER(ORDER BY val) AS tile,
       val
    FROM serie
)
SELECT max(val)
	FROM subset GROUP BY tile ORDER BY tile;

SELECT unnest(percentile_disc(array[0.25,0.5,0.75,1])
    WITHIN GROUP (ORDER BY val))
FROM serie;

---Filter
select produto, quantidade from historico_vendas;

SELECT count(*) contagemTotal,
            count(*) FILTER(WHERE produto = 1) vendaProduto1,
            count(*) FILTER(WHERE produto = 2) vendaProduto2,
            count(*) FILTER(WHERE produto = 3) vendaProduto2
FROM historico_vendas;


SELECT sum(quantidade) contagemTotal,
            sum(quantidade) FILTER(WHERE produto = 1) vendaProduto1,
            sum(quantidade) FILTER(WHERE produto = 2) vendaProduto2,
            sum(quantidade) FILTER(WHERE produto = 3) vendaProduto2
FROM historico_vendas;

---Extra

select * from palavras;
select unnest(string_to_array(sequencia, ',')) AS linhas from palavras;
