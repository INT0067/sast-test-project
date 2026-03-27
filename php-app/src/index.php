<?php

declare(strict_types=1);

function getHealthStatus(): string
{
    return json_encode(['status' => 'ok']);
}

header('Content-Type: application/json');
echo getHealthStatus();
