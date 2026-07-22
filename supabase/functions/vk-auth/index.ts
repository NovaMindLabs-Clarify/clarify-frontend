Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  
  if (code) {
    // Делаем мгновенный невидимый редирект (HTTP 302) прямо на наш Flutter!
    // Браузер даже не покажет белую страницу, он просто перелетит по ссылке.
    return Response.redirect(`http://127.0.0.1:8765/token?code=${code}`, 302);
  }

  // Если кто-то зашел без кода
  return new Response("Ошибка: Код не найден", { status: 400 });
})