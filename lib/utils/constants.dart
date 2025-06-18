// lib/utils/constants.dart

// Para desenvolvimento local (API rodando na mesma máquina que o emulador/dispositivo via USB):
//const String apiBaseUrl =
//    'http://192.168.100.2:5018'; // Use 10.0.2.2 para emulador Android padrão se localhost não funcionar

// Para desenvolvimento local (API rodando em outra máquina na MESMA REDE LOCAL - substitua pelo IP correto):
// const String apiBaseUrl = 'http://192.168.100.2:5018'; // SEU IP LOCAL DA API

// Para produção ou acesso externo:
const String apiBaseUrl =
    'http://farmarcia.nilsensistemas.com.br:5000'; // SUA URL PÚBLICA

// INSTRUÇÕES:
// 1. Descomente a URL que você quer usar.
// 2. Comente as outras URLs.
// 3. Salve o arquivo. O Flutter Hot Reload/Restart deve pegar a nova URL.

// Exemplo para desenvolvimento local com emulador Android padrão:
// const String apiBaseUrl = 'http://10.0.2.2:5018';

// --- NOVA CONSTANTE ADICIONADA ---
// URL pública base para servir as imagens estáticas (ex: avatar do usuário, imagens de produtos/campanhas se servidas diretamente)
const String publicImageBaseUrl =
    'https://sistema.biopoints.com.br'; // Sem barra no final
// --- FIM DA NOVA CONSTANTE ---


// Você pode adicionar outras constantes globais aqui no futuro