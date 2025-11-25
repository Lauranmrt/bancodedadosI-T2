CREATE DATABASE gerenciamento_de_biblioteca;
USE gerenciamento_de_biblioteca;


CREATE TABLE cargo (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome_cargo VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE autor (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome_autor VARCHAR(250) NOT NULL
);

CREATE TABLE editora (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome_editora VARCHAR(250) NOT NULL
);

CREATE TABLE genero (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome_genero VARCHAR(50) NOT NULL
);

CREATE TABLE usuario (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome_usuario VARCHAR(250) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    cpf VARCHAR(14) NOT NULL UNIQUE,
    telefone VARCHAR(20) NOT NULL
);

CREATE TABLE funcionario (
    id INT PRIMARY KEY AUTO_INCREMENT,
    usuario_id INT NOT NULL UNIQUE,
    cargo_id INT NOT NULL,
    salario DOUBLE NOT NULL,
    login VARCHAR(50) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    FOREIGN KEY (usuario_id) REFERENCES usuario(id),
    FOREIGN KEY (cargo_id) REFERENCES cargo(id)
);

CREATE TABLE obra (
    id INT PRIMARY KEY AUTO_INCREMENT,
    titulo VARCHAR(500) NOT NULL,
    autor_id INT NOT NULL,
    editora_id INT NOT NULL,
    genero_id INT NOT NULL,
    ano_lancamento SMALLINT NOT NULL, 
    isbn VARCHAR(20) NOT NULL UNIQUE,
    FOREIGN KEY (autor_id) REFERENCES autor(id),
    FOREIGN KEY (editora_id) REFERENCES editora(id),
    FOREIGN KEY (genero_id) REFERENCES genero(id)
);

CREATE TABLE exemplar (
    id INT PRIMARY KEY AUTO_INCREMENT,
    obra_id INT NOT NULL,
    status_livro VARCHAR(30) NOT NULL DEFAULT 'DISPONIVEL', 
    FOREIGN KEY (obra_id) REFERENCES obra(id)
);

CREATE TABLE emprestimo (
    id INT PRIMARY KEY AUTO_INCREMENT,
    usuario_id INT NOT NULL,
    exemplar_id INT NOT NULL,
    data_emprestimo DATETIME DEFAULT CURRENT_TIMESTAMP,
    data_previsao_devolucao DATE NOT NULL,
    data_devolucao_real DATETIME,
    status_emprestimo VARCHAR(30) NOT NULL DEFAULT 'PENDENTE',
    FOREIGN KEY (usuario_id) REFERENCES usuario(id),
    FOREIGN KEY (exemplar_id) REFERENCES exemplar(id)
);

CREATE TABLE log_auditoria (
    id INT PRIMARY KEY AUTO_INCREMENT,
    acao VARCHAR(50),
    usuario_afetado_id INT,
    exemplar_afetado_id INT,
    data_hora DATETIME DEFAULT CURRENT_TIMESTAMP,
    detalhes VARCHAR(255)
);


-- INSERÇÃO DE DADOS:

INSERT INTO cargo (nome_cargo) VALUES ('Bibliotecário'), ('Atendente');
INSERT INTO autor (nome_autor) VALUES ('J.K. Rowling'), ('J.R.R. Tolkien'), ('Machado de Assis');
INSERT INTO editora (nome_editora) VALUES ('Rocco'), ('HarperCollins'), ('Editora Globo');
INSERT INTO genero (nome_genero) VALUES ('Fantasia'), ('Literatura Brasileira'), ('Aventura');

INSERT INTO usuario (nome_usuario, email, cpf, telefone) VALUES 
('Ana Bibliotecária', 'ana@lib.com', '111.111.111-11', '(66) 9999-1111'),
('João Leitor', 'joao@mail.com', '222.222.222-22', '(66) 9999-2222');

INSERT INTO funcionario (usuario_id, cargo_id, salario, login, senha) VALUES
(1, 1, 3500.00, 'ana.lib', 'senha123');

-- Agora o INSERT funcionará para 1899
INSERT INTO obra (titulo, autor_id, editora_id, genero_id, ano_lancamento, isbn) VALUES
('Harry Potter e a Pedra Filosofal', 1, 1, 1, 1997, '978-8532511010'),
('O Senhor dos Anéis', 2, 2, 1, 1954, '978-8595084742'),
('Dom Casmurro', 3, 3, 2, 1899, '978-8525044648');

INSERT INTO exemplar (obra_id, status_livro) VALUES (1, 'DISPONIVEL'), (1, 'DISPONIVEL'), (1, 'DISPONIVEL');
INSERT INTO exemplar (obra_id, status_livro) VALUES (2, 'DISPONIVEL'), (2, 'DISPONIVEL');
INSERT INTO exemplar (obra_id, status_livro) VALUES (3, 'DISPONIVEL');

-- VIEWS

CREATE VIEW vw_estoque_consolidado AS
SELECT 
    o.id AS obra_id,
    o.titulo,
    o.isbn,
    COUNT(e.id) AS total_fisico,
    SUM(CASE WHEN e.status_livro = 'DISPONIVEL' THEN 1 ELSE 0 END) AS quantidade_disponivel
FROM obra o
LEFT JOIN exemplar e ON o.id = e.obra_id
GROUP BY o.id, o.titulo, o.isbn;

CREATE VIEW vw_historico_completo AS
SELECT 
    u.nome_usuario,
    o.titulo,
    e.id AS exemplar_id,
    emp.data_emprestimo,
    emp.data_devolucao_real,
    emp.status_emprestimo
FROM emprestimo emp
JOIN usuario u ON emp.usuario_id = u.id
JOIN exemplar e ON emp.exemplar_id = e.id
JOIN obra o ON e.obra_id = o.id;

CREATE VIEW vw_emprestimos_vencidos AS
SELECT 
    u.nome_usuario,
    u.email,
    o.titulo,
    emp.data_previsao_devolucao
FROM emprestimo emp
JOIN usuario u ON emp.usuario_id = u.id
JOIN exemplar e ON emp.exemplar_id = e.id
JOIN obra o ON e.obra_id = o.id
WHERE emp.status_emprestimo = 'PENDENTE' 
AND emp.data_previsao_devolucao < CURDATE();


-- PROCEDURES

DELIMITER $$

CREATE PROCEDURE sp_registrar_emprestimo(IN p_usuario_id INT, IN p_obra_id INT)
BEGIN
    DECLARE v_exemplar_id INT;
    
    SELECT id INTO v_exemplar_id 
    FROM exemplar 
    WHERE obra_id = p_obra_id AND status_livro = 'DISPONIVEL' 
    LIMIT 1;
    
    IF v_exemplar_id IS NOT NULL THEN
        INSERT INTO emprestimo (usuario_id, exemplar_id, data_previsao_devolucao, status_emprestimo)
        VALUES (p_usuario_id, v_exemplar_id, DATE_ADD(CURDATE(), INTERVAL 7 DAY), 'PENDENTE');
        
        UPDATE exemplar SET status_livro = 'EMPRESTADO' WHERE id = v_exemplar_id;
        
        SELECT CONCAT('Empréstimo realizado com sucesso! Exemplar: ', v_exemplar_id) AS Mensagem;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Não há exemplares disponíveis para esta obra no momento.';
    END IF;
END $$

CREATE PROCEDURE sp_registrar_devolucao(IN p_emprestimo_id INT)
BEGIN
    DECLARE v_exemplar_id INT;
    
    SELECT exemplar_id INTO v_exemplar_id FROM emprestimo WHERE id = p_emprestimo_id;
    
    UPDATE emprestimo 
    SET status_emprestimo = 'DEVOLVIDO', 
        data_devolucao_real = NOW() 
    WHERE id = p_emprestimo_id;
    
    UPDATE exemplar SET status_livro = 'DISPONIVEL' WHERE id = v_exemplar_id;
    
    SELECT 'Devolução registrada e exemplar disponível novamente.' AS Mensagem;
END $$

DELIMITER ;

-- TRIGGERS

DELIMITER $$

CREATE TRIGGER trg_auditoria_emprestimo
AFTER INSERT ON emprestimo
FOR EACH ROW
BEGIN
    INSERT INTO log_auditoria (acao, usuario_afetado_id, exemplar_afetado_id, detalhes)
    VALUES (
        'NOVO EMPRESTIMO', 
        NEW.usuario_id, 
        NEW.exemplar_id, 
        CONCAT('Empréstimo registrado em ', DATE_FORMAT(NOW(), '%d/%m/%Y às %H:%i'))
    );
END $$

DELIMITER ;



-- 7. SELECTS P/TESTE

SELECT * FROM vw_estoque_consolidado WHERE obra_id = 1;
CALL sp_registrar_emprestimo(2, 1);
SELECT * FROM vw_estoque_consolidado WHERE obra_id = 1;
SELECT * FROM exemplar WHERE obra_id = 1;
SELECT * FROM log_auditoria;