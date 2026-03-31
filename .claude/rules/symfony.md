# Reguli și Convenții de Cod pentru Symfony

Ești un expert în PHP și framework-ul Symfony. Când scrii, revizuiești sau generezi cod pentru aplicații Symfony, trebuie să respecți cu strictețe standardele oficiale de codare, convențiile arhitecturale și PSR-urile suportate.

> **IMPORTANT:** Tot codul și comentariile din cod trebuie scrise **exclusiv în engleză**.

## 1. Principiile Fundamentale și Stilul Codului (PSR-1, PSR-4, PSR-12)

- **Sintaxă și Spațiere:** Adaugă un singur spațiu după virgule și în jurul operatorilor binari (`==`, `&&`, etc.), excepție făcând operatorul de concatenare (`.`). Operatorii unari (`!`, `--`) se lipesc de variabilă.
- **Tipuri stricte:** Utilizează comparația strictă (`===`, `!==`), cu excepția cazurilor în care type-juggling-ul este necesar în mod intenționat.
- **Condiții Yoda:** Folosește condiții Yoda când compari o variabilă cu o expresie (ex: `if (true === $status)`) pentru a evita asignarea accidentală în if-uri. Se aplică la `==`, `!=`, `===`, `!==`.
- **Instrucțiuni de Return:** Folosește `return null;` când metoda returnează explicit null și `return;` când funcția întoarce `void`. Adaugă o linie goală înainte de `return`, excepție făcând cazurile în care este singura instrucțiune dintr-un bloc.
- **Structura Claselor:**
    - O singură clasă pe fișier (excepție: clase helper private care nu sunt exportate/instanțiate extern).
    - Declară moștenirea (`extends`) și interfețele (`implements`) pe aceeași linie cu clasa.
    - Ordonează proprietățile înainte de metode. Ordinea de vizibilitate: `public`, `protected`, apoi `private`. Funcțiile constructor și metodele de setup pentru teste (`setUp()`, `tearDown()`) trebuie să fie primele metode.
    - În cazul *constructor property promotion*, pune fiecare parametru pe o linie nouă, urmat de virgulă (inclusiv la ultimul parametru).

## 2. Convenții de Denumire (Naming Conventions)

- **Variabile și Funcții/Metode:** Folosește `camelCase` (ex. `$isReady`, `calculateTotal()`).
- **Constante:** Folosește `SCREAMING_SNAKE_CASE` (ex. `Command::IS_ARRAY`).
- **Clase, Interfețe, Atribute și Enum-uri:** Folosește `UpperCamelCase`.
    - Interfețele trebuie să aibă sufixul `Interface`.
    - Trait-urile trebuie să aibă sufixul `Trait`.
    - Excepțiile au sufixul `Exception`.
    - Clasele abstracte trebuie să aibă prefixul `Abstract` (excepție: testele care se termină în `TestCase`).
- **Parametri, Rute și Variabile Twig:** Folosește `snake_case` (ex. `framework.csrf_protection`).
- **Type-hinting:** Pentru PHPDoc și declararea tipurilor, folosește formele scurte și standardizate: `bool` (nu boolean), `int` (nu integer), `float` (nu double).

## 3. Servicii și Dependency Injection

- **Nume de Servicii:** Numele unui serviciu principal trebuie să fie identic cu Fully Qualified Class Name (FQCN) (ex. `App\Service\MailerService`).
- **Servicii Multiple:** Dacă declari mai multe servicii pentru aceeași clasă, folosește FQCN pentru cel principal, iar pentru restul folosește nume lower-case cu underscore (ex. `app.custom_mailer`).
- Numele parametrilor din Container folosesc litere mici și underscore (excepție făcând citirea directă din mediu cu sintaxa `%env(API_KEY)%`).

## 4. Relații de Obiecte și Denumirea Metodelor (One-to-Many)

Când un obiect conține o colecție principală (o singură relație majoră), metodele se denumesc simplu: `get()`, `set()`, `has()`, `add()`, `remove()`, `all()`, `clear()`.
Dacă obiectul are multiple colecții secundare, adaugă numele elementului:
- `getXXXs()` și `addXXX()`
- `removeXXX()`
- **Atenție:** Metoda `setXXX()` înlocuiește sau adaugă elemente noi. Metoda `replaceXXX()` doar modifică elementele existente (aruncă o excepție dacă primește o cheie neînregistrată).

## 5. Excepții și Mesaje de Eroare

- **Interpolarea mesajelor:** Folosește `sprintf()` pentru a introduce variabile în mesajele excepțiilor, evitând concatenarea cu `.`.
- **Fără Backticks:** Nu folosi backticks (\`). Dacă te referi la opțiuni sau nume de variabile, pune-le între ghilimele duble (`"nume_variabila"`).
- **Format:** Un mesaj de eroare începe cu literă mare și se termină obligatoriu cu un punct (`.`).
- **Tipuri la rulare:** Când incluzi o clasă în mesaj, folosește `get_debug_type($var)` în loc de `$var::class` pentru a trata corect tipurile primitive și clasele anonime.

## 6. Comentarii și Documentație (PHPDoc)

- Adaugă blocuri PHPDoc DOAR atunci când aduc o valoare adăugată (ex. arrays generice precum `array<int, string>`). Nu duplica informații deja clare prin native type hints.
- Când declari tipuri care includ `null`, acesta se pune ultimul (ex. `@param string|null $name`).
- Grupează adnotările similare. Lasă un rând gol între grupuri diferite (ex. între `@param` și `@return`).
- Omite tag-ul `@return` dacă metoda nu returnează nimic sau întoarce `void`. Nu folosi blocuri PHPDoc pe o singură linie (`/** ... */`).

## 7. Deprecieri (Deprecations)

Dacă sugerezi refactorizarea unui cod marcat spre depreciere, asigură-te că folosești `@deprecated since Symfony [Versiune], use [Alternativă] instead.` în PHPDoc. În codul efectiv, se folosește metoda `trigger_deprecation()` pentru a alerta dezvoltatorul (ex: `trigger_deprecation('symfony/package', '5.1', 'The %s class is deprecated...', __CLASS__);`).
