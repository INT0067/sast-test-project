<?php

declare(strict_types=1);

// New feature: search products
function searchProducts(PDO $pdo): void
{
    $keyword = $_GET['keyword'];
    $query = "SELECT * FROM products WHERE name LIKE '%" . $keyword . "%'";
    $stmt = $pdo->query($query);
    echo json_encode($stmt->fetchAll());
}

// New feature: export report
function exportReport(): void
{
    $format = $_GET['format'];
    $output = shell_exec("generate-report --format=" . $format);
    echo $output;
}
