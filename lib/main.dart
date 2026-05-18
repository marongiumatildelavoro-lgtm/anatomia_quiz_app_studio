import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;

void main() {
  runApp(const MedicalPlatformApp());
}

class MedicalPlatformApp extends StatelessWidget {
  const MedicalPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedPraxis Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F172A), // Slate 900
        scaffoldBackgroundColor: const Color(0xFF020617), // Deep Navy 950
        cardColor: const Color(0xFF1E293B), // Slate 800
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // ==========================================
  // CONFIGURAZIONE LINK GOOGLE SHEETS (OPZIONE A)
  // Incolla qui i link CSV di ciascuna scheda pubblicata sul Web
  // ==========================================
  final Map<String, String> linkSchedeOrgani = {
    'cuore': 'https://google.com',
    'polmoni': 'INCOLLA_QUI_IL_LINK_CSV_DELLA_SCHEDA_POLMONI',
    'encefalo': 'INCOLLA_QUI_IL_LINK_CSV_DELLA_SCHEDA_ENCEFALO',
  };

  final Map<String, Map<String, String>> localizzazione = {
    'en': {
      'titolo': 'MedPraxis Quiz',
      'sottotitolo': 'Advanced Medical Science & Diagnostics Hub',
      'seleziona_materia': 'Select Medical Discipline',
      'base_titolo': 'Core & Academic Level',
      'base_desc': 'Designed for High School and Undergraduate University Students. Balanced rotation of all organ subcategories.',
      'difficile_titolo': 'Advanced & Specialist Level',
      'difficile_desc': 'Tailored for Clinicians, Board Professionals, and Postgraduates. High-density topographical variations.',
      'cambia_lingua': 'Change Language',
      'disclaimer': 'Medical Disclaimer: This AI-powered platform is for educational and self-assessment purposes only. It does not constitute medical advice, diagnosis, or clinical guidelines. The authors assume no liability for errors or clinical misinterpretations.',
      'privacy': 'Privacy Policy', 'terms': 'Terms of Service', 'cookies': 'Cookie Policy',
      'no_domande': 'No new questions available for the selected criteria.',
      'avvia': 'Start Session',
      'caricamento': 'Synchronizing Multi-Tab Medical Database from Google Sheets...',
      'selezionato': 'Selected',
      'tag1': 'Anatomy Quiz', 'tag2': 'Physiology Quiz', 'tag3': 'Medical Exam', 'tag4': 'USMLE Prep', 'tag5': 'Clinical Board'
    },
    'it': {
      'titolo': 'MedPraxis Quiz',
      'sottotitolo': 'Hub Avanzato di Diagnostica e Nozioni Mediche',
      'seleziona_materia': 'Seleziona Disciplina Medica',
      'base_titolo': 'Livello Core e Accademico',
      'base_desc': 'Sviluppato per studenti di scuole superiori e corsi universitari triennali. Rotazione bilanciata degli organi.',
      'difficile_titolo': 'Livello Avanzato e Specialistico',
      'difficile_desc': 'Configurato per medici, professionisti sanitari e scuole di specializzazione. Massima densità topografica.',
      'cambia_lingua': 'Cambia Lingua',
      'disclaimer': 'Disclaimer Medico: Questa piattaforma ha scopi esclusivamente didattici e di autovalutazione. Non costituisce consulenza medica, diagnosi o protocollo clinico. Gli autori declinano ogni responsabilità per errori o interpretazioni cliniche.',
      'privacy': 'Privacy Policy', 'terms': 'Termini di Servizio', 'cookies': 'Uso dei Cookie',
      'no_domande': 'Nessuna nuova domanda disponibile. Controlla il foglio o i criteri.',
      'avvia': 'Avvia Sessione',
      'caricamento': 'Sincronizzazione multi-scheda in tempo reale da Google Sheets...',
      'selezionato': 'Selezionato',
      'tag1': 'Quiz Anatomia', 'tag2': 'Quiz Fisiologia', 'tag3': 'Test Medicina', 'tag4': 'Professioni Sanitarie', 'tag5': 'Specializzazione Chirurgia'
    }
  };

  late String linguaAttiva;
  List<Map<String, dynamic>> tutteLeDomande = [];
  Set<String> materieDisponibili = {};
  String? materiaSelezionata;
  bool caricamentoInCorso = true;
  List<String> codiciDomandeGiaViste = [];

  @override
  void initState() {
    super.initState();
    String localeIniziale = ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    linguaAttiva = localizzazione.containsKey(localeIniziale) ? localeIniziale : 'en';
    _scaricaTutteLeSchede();
  }

  // MOTORE DI SCARICAMENTO ASINCRONO PARALLELO DELLE SCHEDE
  Future<void> _scaricaTutteLeSchede() async {
    List<Map<String, dynamic>> temporaneoMisto = [];
    Set<String> materieTrovate = {};

    try {
      // Esegue le chiamate di rete in parallelo per azzerare i tempi di caricamento
      final chiamate = linkSchedeOrgani.entries.map((entry) async {
        String nomeScheda = entry.key;
        String url = entry.value;

        if (url.startsWith('INCOLLA_QUI')) return;

        final risposta = await http.get(Uri.parse(url));
        if (risposta.statusCode == 200) {
          final stringaDati = utf8.decode(risposta.bodyBytes);
          final righe = const LineSplitter().convert(stringaDati);
          if (righe.length <= 1) return;

          for (int i = 1; i < righe.length; i++) {
            final celle = _analizzaRigaCSV(righe[i]);
            if (celle.length >= 13) {
              String codiceDomanda = celle[0].trim();
              if (codiceDomanda.toLowerCase() == 'codice' || codiceDomanda.isEmpty) continue;

              String materia = celle[2].trim().toUpperCase();
              if (materia.isNotEmpty) materieTrovate.add(materia);

              temporaneoMisto.add({
                'codice': codiceDomanda,
                'lingua': celle[1].trim().toLowerCase(),
                'materia': materia,
                'sottocategoria': nomeScheda, // Forza il nome della scheda come sottocategoria
                'livello': celle[4].trim().toLowerCase(),
                'testo': celle[5].trim(),
                'opzioni': [celle[6].trim(), celle[7].trim(), celle[8].trim(), celle[9].trim(), celle[10].trim()],
                'risposta_corretta': celle[11].trim().toUpperCase(),
                'spiegazione': celle[12].trim(),
              });
            }
          }
        }
      }).toList();

      await Future.wait(chiamate);

      setState(() {
        tutteLeDomande = temporaneoMisto;
        materieDisponibili = materieTrovate;
        if (materieDisponibili.isNotEmpty) {
          materiaSelezionata = materieDisponibili.first;
        }
        caricamentoInCorso = false;
      });
    } catch (e) {
      setState(() { caricamentoInCorso = false; });
      debugPrint("Errore critico di sincronizzazione multi-scheda: $e");
    }
  }

  List<String> _analizzaRigaCSV(String riga) {
    List<String> risultato = [];
    StringBuffer buffer = StringBuffer();
    bool dentroVirgolette = false;

    for (int i = 0; i < riga.length; i++) {
      String carattere = riga[i];
      if (carattere == '"') {
        dentroVirgolette = !dentroVirgolette;
      } else if (carattere == ',' && !dentroVirgolette) {
        risultato.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(carattere);
      }
    }
    risultato.add(buffer.toString());
    return risultato;
  }

  void _mostraPannelloImpostazioni() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(localizzazione[linguaAttiva]!['cambia_lingua']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('Italiano (IT)', style: TextStyle(color: Colors.white)),
                onTap: () { setState(() { linguaAttiva = 'it'; }); Navigator.pop(context); },
              ),
              ListTile(
                title: const Text('English (EN)', style: TextStyle(color: Colors.white)),
                onTap: () { setState(() { linguaAttiva = 'en'; }); Navigator.pop(context); },
              ),
            ],
          ),
        );
      },
    );
  }

  // ALGORITMO DI SELEZIONE DISTRIBUITA BILANCIATA ROUND-ROBIN CON ESCLUSIONE
  void _avviaQuiz(String livello) {
    if (materiaSelezionata == null) return;

    List<Map<String, dynamic>> disponibili = tutteLeDomande.where((d) => 
      d['lingua'] == linguaAttiva && d['livello'] == livello && d['materia'] == materiaSelezionata
    ).toList();

    if (disponibili.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizzazione[linguaAttiva]!['no_domande']!)));
      return;
    }

    List<Map<String, dynamic>> inedite = disponibili.where((d) => !codiciDomandeGiaViste.contains(d['codice'])).toList();

    // Sbarramento di sicurezza: se esaurite, svuota la cache locale di quel livello e riparte
    if (inedite.isEmpty) {
      codiciDomandeGiaViste.removeWhere((id) => disponibili.any((d) => d['codice'] == id));
      inedite = disponibili;
    }

    // Raggruppa le domande inedite per organo (sottocategoria)
    Map<String, List<Map<String, dynamic>>> mappaOrgani = {};
    for (var d in inedite) {
      mappaOrgani.putIfAbsent(d['sottocategoria'], () => []).add(d);
    }

    // Mescola ciascun gruppo interno singolarmente
    mappaOrgani.forEach((key, lista) => lista.shuffle());

    List<Map<String, dynamic>> sessioneQuiz = [];
    List<String> chiaviOrgani = mappaOrgani.keys.toList();
    int contatoreCiclo = 0;

    // Estrazione ciclica bilanciata (Round-Robin): prende una domanda per organo alternandole
    while (sessioneQuiz.length < 20 && chiaviOrgani.isNotEmpty) {
      String organoCorrente = chiaviOrgani[contatoreCiclo % chiaviOrgani.length];
      if (mappaOrgani[organoCorrente]!.isNotEmpty) {
        sessioneQuiz.add(mappaOrgani[organoCorrente]!.removeAt(0));
      } else {
        chiaviOrgani.remove(organoCorrente);
      }
      contatoreCiclo++;
    }

    // Mescola il blocco finale da 20 per azzerare la prevedibilità dell'esame
    sessioneQuiz.shuffle();

    // Aggiunge i codici alla lista nera anti-ripetizione
    for (var d in sessioneQuiz) {
      codiciDomandeGiaViste.add(d['codice']);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QuizEngineScreen(domandeSessione: sessioneQuiz, lingua: linguaAttiva)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = localizzazione[linguaAttiva]!;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(t['titolo']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(icon: const Icon(Icons.settings, color: Color(0xFF94A3B8)), onPressed: _mostraPannelloImpostazioni),
          const SizedBox(width: 16),
        ],
      ),
      body: caricamentoInCorso 
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(color: Colors.deepPurpleAccent), const SizedBox(height: 20), Text(t['caricamento']!, style: const TextStyle(color: Colors.grey, fontSize: 16))]))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 10, runSpacing: 10,
                              children: [_seoTag(t['tag1']!), _seoTag(t['tag2']!), _seoTag(t['tag3']!), _seoTag(t['tag4']!), _seoTag(t['tag5']!)],
                            ),
                            const SizedBox(height: 40),
                            Text(t['titolo']!, style: Theme.of(context).textTheme.displayLarge, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Text(t['sottotitolo']!, style: const TextStyle(fontSize: 18, color: Color(0xFF38BDF8)), textAlign: TextAlign.center),
                            const SizedBox(height: 40),
                            Text(t['seleziona_materia']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12, runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: auditedChips(),
                            ),
                            const SizedBox(height: 50),
                            isDesktop 
                                ? Row(children: [
                                    Expanded(child: _cardLivello(Icons.school, t['base_titolo']!, t['base_desc']!, Colors.emerald, () => _avviaQuiz('base'))),
                                    const SizedBox(width: 24),
                                    Expanded(child: _cardLivello(Icons.local_hospital, t['difficile_titolo']!, t['difficile_desc']!, Colors.roseAccent, () => _avviaQuiz('difficile'))),
                                  ])
                                : Column(children: [
                                    _cardLivello(Icons.school, t['base_titolo']!, t['base_desc']!, Colors.emerald, () => _avviaQuiz('base')),
                                    const SizedBox(height: 24),
                                    _cardLivello(Icons.local_hospital, t['difficile_titolo']!, t['difficile_desc']!, Colors.roseAccent, () => _avviaQuiz('difficile')),
                                  ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFooter(t)
              ],
            ),
    );
  }

  List<Widget> auditedChips() {
    return materieDisponibili.map((materia) {
      bool isSelected = materiaSelezionata == materia;
      return ChoiceChip(
        label: Text(materia, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
        selected: isSelected,
        selectedColor: const Color(0xFF38BDF8),
        backgroundColor: const Color(0xFF1E293B),
        onSelected: (bool selected) { if (selected) { setState(() { materiaSelezionata = materia; }); } },
      );
    }).toList();
  }

  Widget _seoTag(String testo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(20)),
    child: Text('#$testo', style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w600)),
  );

  Widget _cardLivello(IconData icona, String titolo, String desc, Color colore, VoidCallback onClick) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icona, size: 40, color: colore),
          const SizedBox(height: 16),
          Text(titolo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(desc, style: const TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onClick, style: ElevatedButton.styleFrom(backgroundColor: colore, foregroundColor: Colors.black), child: Text(localizzazione[linguaAttiva]!['avvia']!))
        ],
      ),
    ),
  );

  Widget _buildFooter(Map<String, String> t) => Container(
    color: const Color(0xFF0F172A), padding: const EdgeInsets.all(24.0),
    child: Column(
      children: [
        Text(t['disclaimer']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.justify),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(t['privacy']!, style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
          const Text('  •  ', style: TextStyle(color: Colors.grey)),
          Text(t['terms']!, style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
          const Text('  •  ', style: TextStyle(color: Colors.grey)),
          Text(t['cookies']!, style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
        ]),
      ],
    ),
  );
}

class QuizEngineScreen extends StatefulWidget {
  final List<Map<String, dynamic>> domandeSessione;
  final String lingua;
  const QuizEngineScreen({super.key, required this.domandeSessione, required this.lingua});

  @override
  State<QuizEngineScreen> createState() => _QuizEngineScreenState();
}

class _QuizEngineScreenState extends State<QuizEngineScreen> {
  int indiceCorrente = 0; int risposteEsatte = 0; String? opzioneSelezionata; bool rispostaInviata = false;
  int secondiTrascorsi = 0; Timer? timerCronometro;

  @override
  void initState() { super.initState(); _avviaCronometro(); }

  void _avviaCronometro() {
    timerCronometro = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() { if (secondiTrascorsi >= 300) { timerCronometro?.cancel(); _mostraSchermataRisultati(); } else { secondiTrascorsi++; } });
    });
  }

  String _formattaTempo(int secondi) {
    return '${(secondi ~/ 60).toString().padLeft(2, '0')}:${(secondi % 60).toString().padLeft(2, '0')}';
  }

  void _valutaRisposta() {
    if (opzioneSelezionata == null) return;
    String corretta = widget.domandeSessione[indiceCorrente]['risposta_corretta'].toString().toUpperCase();
    int idx = corretta.codeUnitAt(0) - 65;
    if (idx < 0 || idx >= widget.domandeSessione[indiceCorrente]['opzioni'].length) idx = 0;
    setState(() { rispostaInviata = true; if (opzioneSelezionata == widget.domandeSessione[indiceCorrente]['opzioni'][idx]) risposteEsatte++; });
  }

  void _proseguiQuiz() {
    if (indiceCorrente < widget.domandeSessione.length - 1) {
      setState(() { indiceCorrente++; opzioneSelezionata = null; rispostaInviata = false; });
    } else { timerCronometro?.cancel(); _mostraSchermataRisultati(); }
  }

  void _mostraSchermataRisultati() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResultsDashboard(punteggio: risposteEsatte, totale: widget.domandeSessione.length, tempoImpiegato: secondiTrascorsi, lingua: widget.lingua)));
  }

  @override
  void dispose() { timerCronometro?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.domandeSessione[indiceCorrente];
    List<dynamic> opzioni = d['opzioni'];

    return Scaffold(
      appBar: AppBar(
        title: Text('${d['materia']} : ${d['sottocategoria'].toString().toUpperCase()}'),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Row(children: [const Icon(Icons.timer, color: Colors.amber, size: 20), const SizedBox(width: 6), Text(_formattaTempo(secondiTrascorsi), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber))]),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: (indiceCorrente + 1) / widget.domandeSessione.length, backgroundColor: const Color(0xFF1E293B), color: Colors.blueAccent),
                const SizedBox(height: 40),
                Text(d['testo'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
                const SizedBox(height: 30),
                ...opzioni.map((opzione) {
                  bool isSelected = opzioneSelezionata == opzione;
                  String letteraCorretta = d['risposta_corretta'].toString().toUpperCase();
                  int indiceMappaLettera = letteraCorretta.codeUnitAt(0) - 65;
                  if(indiceMappaLettera < 0 || indiceMappaLettera >= opzioni.length) indiceMappaLettera = 0;
                  bool isCorrectAnswer = opzione == d['opzioni'][indiceMappaLettera];

                  Color cardColor = const Color(0xFF1E293B); Color borderColor = const Color(0xFF334155);

                  if (rispostaInviata) {
                    if (isCorrectAnswer) { cardColor = Colors.emerald.withOpacity(0.2); borderColor = Colors.emerald; }
                    else if (isSelected) { cardColor = Colors.rose.withOpacity(0.2); borderColor = Colors.rose; }
                  } else if (isSelected) { borderColor = Colors.blueAccent; cardColor = const Color(0xFF334155); }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: Container(
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 2)),
                      child: ListTile(
                        title: Text(opzione, style: const TextStyle(fontSize: 16)),
                        onTap: rispostaInviata ? null : () { setState(() { opzioneSelezionata = opzione; }); },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 30),
                if (rispostaInviata) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF334155))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RAZIONALE CLINICO / RATIONALE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                        const SizedBox(height: 10),
                        Text(d['spiegazione'], style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                ElevatedButton(
                  onPressed: opzioneSelezionata == null ? null : (rispostaInviata ? _proseguiQuiz : _valutaRisposta),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), backgroundColor: Colors.blueAccent),
                  child: Text(rispostaInviata ? 'NEXT QUESTION' : 'SUBMIT ANSWER', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResultsDashboard extends StatelessWidget {
  final int punteggio; final int totale; final int tempoImpiegato; final String lingua;
  const ResultsDashboard({super.key, required this.punteggio, required this.totale, required this.tempoImpiegato, required this.lingua});

  @override
  Widget build(BuildContext context) {
    double ratio = (punteggio / totale) * 100; bool superato = ratio >= 75.0;
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(superato ? Icons.check_circle : Icons.error, size: 80, color: superato ? Colors.emerald : Colors.rose),
              const SizedBox(height: 20),
              Text('Score: $punteggio / $totale (${ratio.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Time: ${tempoImpiegato ~/ 60}m ${tempoImpiegato % 60}s'),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text('Return to Hub'))
            ],
          ),
        ),
      ),
    );
  }
}
