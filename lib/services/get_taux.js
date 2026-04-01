const TauxReference = require('./taux_reference');
const taux = new TauxReference();

taux.getTauxReference()
  .then(result => console.log('Result:', result))
  .catch(err => console.error(err));