// Edge-runtime dispatch router for poke5e-offline.
//
// Derived from Supabase's self-hosted `functions/main` router, reduced to just
// the dispatch path — JWT verification is intentionally disabled here (the stack
// sets VERIFY_JWT=false; the user-assets function authorizes via poke5e's own
// read/write keys, not Supabase auth).
//
// Routes  /<function-name>[/...]  ->  /home/deno/functions/<function-name>

Deno.serve(async (req: Request) => {
  const { pathname } = new URL(req.url)
  const serviceName = pathname.split("/")[1]

  if (!serviceName) {
    return Response.json({ msg: "missing function name in request" }, { status: 400 })
  }

  const servicePath = `/home/deno/functions/${serviceName}`

  // Prefer the function's own import map so upstream dependency changes flow
  // through automatically on update; fall back to the shared one.
  let importMapPath = `${servicePath}/deno.json`
  try {
    await Deno.stat(importMapPath)
  } catch {
    importMapPath = "/home/deno/functions/deno.jsonc"
  }

  try {
    // @ts-ignore - EdgeRuntime is provided by the supabase/edge-runtime host.
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath,
      memoryLimitMb: 150,
      workerTimeoutMs: 60_000,
      noModuleCache: false,
      importMapPath,
      envVars: Object.entries(Deno.env.toObject()),
    })
    return await worker.fetch(req)
  } catch (e) {
    return Response.json({ msg: String(e) }, { status: 500 })
  }
})
