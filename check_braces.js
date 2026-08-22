const fs = require('fs');

function checkFile(file) {
    const content = fs.readFileSync(file, 'utf8');
    let balance = 0;
    for(let char of content) {
        if(char === '{') balance++;
        if(char === '}') balance--;
    }
    console.log(file, 'Balance:', balance);
}

checkFile('lib/screens/settings/settings_screen.dart');
checkFile('lib/services/sms_service.dart');
checkFile('lib/services/payment_gateway_service.dart');
checkFile('lib/services/supabase_sync_service.dart');
checkFile('lib/providers/settings_provider.dart');
