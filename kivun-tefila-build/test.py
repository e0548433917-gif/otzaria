import sys, asyncio
from playwright.async_api import async_playwright

DIR, CITY = sys.argv[1], sys.argv[2]


async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={"width": 1366, "height": 768})
        errs, nets = [], []
        pg.on("pageerror", lambda e: errs.append(str(e)))
        pg.on("console", lambda m: m.type == "error" and errs.append(m.text))

        async def block(r):
            if r.request.url.startswith("http"):
                nets.append(r.request.url[:80])
                await r.abort()
            else:
                await r.continue_()
        await pg.route("**/*", block)
        await pg.goto("file://" + DIR + "/index.html")
        await pg.wait_for_timeout(500)
        idx = await pg.evaluate("[...document.getElementById('city').options].findIndex(o=>o.text===%r)" % CITY)
        val = await pg.evaluate("document.getElementById('city').options[%d].value" % idx)
        await pg.select_option("#city", val)
        pass
        await pg.wait_for_timeout(1500)
        paths = await pg.evaluate("document.querySelectorAll('#map path').length")
        syn = await pg.evaluate("[...document.querySelectorAll('#map text')].filter(t=>t.textContent==='✡').length")
        txt = await pg.text_content("#stTxt")
        names = await pg.evaluate("document.querySelectorAll('#stNames option').length")
        first = await pg.evaluate("document.querySelector('#stNames option')&&document.querySelector('#stNames option').value")
        await pg.fill("#stQ", first or "")
        await pg.click("#stGo")
        await pg.wait_for_timeout(300)
        txt2 = await pg.text_content("#stTxt")
        await pg.fill("#plName", "בדיקה")
        await pg.click("#plSave")
        pl = await pg.evaluate("document.getElementById('pl').options.length")
        h = await pg.evaluate("document.documentElement.scrollHeight")
        await pg.screenshot(path=DIR + "/../../shot.png", full_page=False)
        print(f"paths={paths} syn={syn} names={names} places_opts={pl} pageHeight={h}")
        print("txt:", txt)
        print("search:", txt2)
        print("errors:", errs or "none")
        print("net blocked:", nets or "none")
        await b.close()

asyncio.run(main())
