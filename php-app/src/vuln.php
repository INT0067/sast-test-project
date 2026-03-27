<?php

declare(strict_types=1);

// Vulnerability 1: SQL Injection
function getUser(PDO $pdo): void
{
    $id = $_GET['id'];
    $query = "SELECT * FROM users WHERE id = " . $id;
    $stmt = $pdo->query($query);
    echo json_encode($stmt->fetchAll());
}

// Vulnerability 2: XSS (Cross-Site Scripting)
function displayName(): void
{
    $name = $_POST['name'];
    echo "<h1>Welcome, " . $name . "</h1>";
}

// Vulnerability 3: Command Injection
function pingHost(): void
{
    $host = $_GET['host'];
    $output = shell_exec("ping -c 1 " . $host);
    echo $output;
}

// Vulnerability 4: Path Traversal
function readFile(): void
{
    $file = $_GET['file'];
    $content = file_get_contents("/var/www/uploads/" . $file);
    echo $content;
}

// Vulnerability 5: Hardcoded credentials
function connectDB(): PDO
{
    $password = "admin123";
    return new PDO("mysql:host=localhost;dbname=app", "root", $password);
}

// Vulnerability 6: Insecure deserialization
function loadSession(): mixed
{
    $data = $_COOKIE['session_data'];
    return unserialize($data);
}
