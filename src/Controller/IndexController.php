<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

class IndexController extends AbstractController
{
  #[Route('/', name: 'app_index', methods: ['GET'])]
  public function index(): Response
  {
    return new Response('<html><body><p>It\'s work</p></body></html>');
  }
}

