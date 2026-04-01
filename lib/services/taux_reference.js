const puppeteer = require('puppeteer-core');

class TauxReference {
  constructor() {
    this.url = 'https://www.brh.ht/taux-du-jour/';
  }

  async getTauxReference() {
    const browser = await puppeteer.launch({
      executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });

    const page = await browser.newPage();
    try {
      await page.goto(this.url, { waitUntil: 'networkidle2' });

      // On utilise evaluate pour extraire précisément les données dans le DOM
      const data = await page.evaluate(() => {
        // 1. Récupérer la date
        const dateElement = document.querySelector('.col-sm-9');
        const dateRaw = dateElement ? dateElement.innerText.trim() : 'Date inconnue';

        // 2. Trouver la ligne spécifique au "TAUX DE REFERENCE"
        // On cherche toutes les lignes avec la classe 't-imp'
        const rows = Array.from(document.querySelectorAll('tr.t-imp'));
        const refRow = rows.find(row => row.innerText.includes('MARCHE INFORMEL'));

        let tauxValue = 'Non trouvé';
        if (refRow) {
          // Dans cette ligne, le taux est dans la deuxième cellule (td)
          const cells = refRow.querySelectorAll('td');
          if (cells.length >= 2) {
            tauxValue = cells[1].innerText.trim();
          }
        }

        return {
          titre: dateRaw,
          taux: tauxValue
        };
      });

      await browser.close();
      return data;
    } catch (err) {
      await browser.close();
      throw err;
    }
  }
}

module.exports = TauxReference;