import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailValidator {
  // Comprehensive email regex pattern
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  // List of common disposable/fake email domains
  static final List<String> _disposableDomains = [
    '10minutemail.com',
    '20minutemail.com',
    '33mail.com',
    'guerrillamail.com',
    'mailinator.com',
    'tempmail.com',
    'throwaway.email',
    'temp-mail.org',
    'fakeinbox.com',
    'mohmal.com',
    'trashmail.com',
    'yopmail.com',
    'getnada.com',
    'maildrop.cc',
    'sharklasers.com',
    'grr.la',
    'guerrillamailblock.com',
    'pokemail.net',
    'spam4.me',
    'bccto.me',
    'chammy.info',
    'devnullmail.com',
    'dispostable.com',
    'emailondeck.com',
    'fakemailgenerator.com',
    'getairmail.com',
    'inboxkitten.com',
    'mailcatch.com',
    'mintemail.com',
    'mytrashmail.com',
    'put2.net',
    'quickinbox.com',
    'rcpt.at',
    'receiveee.com',
    'send22u.info',
    'tempr.email',
    'tmpmail.org',
    'tmpmail.net',
    'tmpmail.io',
    'tmpinbox.com',
    'tmail.ws',
    'trbvm.com',
    'trbvo.com',
    'tyldd.com',
  ];

  /// Validates email format and checks for disposable/fake email domains
  /// Returns null if valid, error message if invalid
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Please enter your email';
    }

    final trimmedEmail = email.trim().toLowerCase();

    // Check basic format
    if (!_emailRegex.hasMatch(trimmedEmail)) {
      return 'Please enter a valid email address';
    }

    // Check for common issues
    if (trimmedEmail.startsWith('.') || trimmedEmail.startsWith('@')) {
      return 'Email cannot start with a dot or @';
    }

    if (trimmedEmail.contains('..')) {
      return 'Email cannot contain consecutive dots';
    }

    if (trimmedEmail.endsWith('.') || trimmedEmail.endsWith('@')) {
      return 'Email cannot end with a dot or @';
    }

    // Extract domain
    final parts = trimmedEmail.split('@');
    if (parts.length != 2) {
      return 'Please enter a valid email address';
    }

    final domain = parts[1].toLowerCase();

    // Check for disposable/fake email domains
    if (_isDisposableDomain(domain)) {
      return 'Disposable email addresses are not allowed. Please use a real email address.';
    }

    // Check domain format
    if (domain.length < 3) {
      return 'Email domain is too short';
    }

    if (!domain.contains('.')) {
      return 'Please enter a valid email address with a domain';
    }

    // Check for valid TLD (top-level domain)
    final tld = domain.split('.').last;
    if (tld.length < 2) {
      return 'Please enter a valid email address';
    }

    // Additional checks for common fake patterns
    if (_hasFakePattern(trimmedEmail)) {
      return 'Please enter a real email address';
    }

    return null; // Email is valid
  }

  /// Checks if the domain is a known disposable email service
  static bool _isDisposableDomain(String domain) {
    // Remove www. prefix if present
    final cleanDomain = domain.replaceFirst(RegExp(r'^www\.'), '');
    
    // Check exact match
    if (_disposableDomains.contains(cleanDomain)) {
      return true;
    }

    // Check for subdomains of disposable services
    for (final disposableDomain in _disposableDomains) {
      if (cleanDomain.endsWith('.$disposableDomain') || 
          cleanDomain == disposableDomain) {
        return true;
      }
    }

    return false;
  }

  /// Checks for common fake email patterns
  static bool _hasFakePattern(String email) {
    // Check for obvious fake patterns
    final fakePatterns = [
      'test@test',
      'fake@fake',
      'example@example',
      'admin@admin',
      'user@user',
      'email@email',
      'mail@mail',
      '123@123',
      'abc@abc',
    ];

    for (final pattern in fakePatterns) {
      if (email.contains(pattern)) {
        return true;
      }
    }

    // Check for emails with only numbers before @
    final localPart = email.split('@').first;
    if (RegExp(r'^\d+$').hasMatch(localPart) && localPart.length < 3) {
      return true;
    }

    return false;
  }

  /// Quick validation for format only (without disposable check)
  static bool isValidFormat(String? email) {
    if (email == null || email.trim().isEmpty) {
      return false;
    }
    return _emailRegex.hasMatch(email.trim());
  }

  /// Validates email format and checks domain existence via DNS MX records
  /// This is an async method that should be used for thorough validation
  /// Returns null if valid, error message if invalid
  static Future<String?> validateEmailWithDomainCheck(String? email) async {
    // First do basic validation
    final basicValidation = validateEmail(email);
    if (basicValidation != null) {
      return basicValidation;
    }

    // Extract domain
    final trimmedEmail = email!.trim().toLowerCase();
    final parts = trimmedEmail.split('@');
    if (parts.length != 2) {
      return 'Please enter a valid email address';
    }

    final domain = parts[1].toLowerCase();

    // Check if domain exists and has MX records (can receive emails)
    try {
      final hasValidDomain = await _checkDomainExists(domain);
      if (!hasValidDomain) {
        return 'This email domain does not exist or cannot receive emails. Please enter a valid email address.';
      }
    } catch (e) {
      // If DNS check fails (network issue, etc.), allow the email but log the error
      print('DNS check failed for domain $domain: $e');
      // Don't block the user if DNS check fails - might be network issue
      // The basic validation already passed, so we'll allow it
    }

    return null; // Email is valid
  }

  /// Checks if domain exists and has MX records using DNS over HTTPS
  static Future<bool> _checkDomainExists(String domain) async {
    try {
      // Use Cloudflare's DNS over HTTPS API (free, no API key required)
      final url = Uri.parse('https://cloudflare-dns.com/dns-query?name=$domain&type=MX');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/dns-json',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('DNS lookup timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if we got MX records
        if (data['Answer'] != null && (data['Answer'] as List).isNotEmpty) {
          // Check if any record is of type MX (15)
          final answers = data['Answer'] as List;
          for (var answer in answers) {
            if (answer['type'] == 15) { // MX record type
              return true;
            }
          }
        }
        
        // If no MX records, check if domain exists (has A or AAAA records)
        // Some domains might use A records for mail servers
        final urlA = Uri.parse('https://cloudflare-dns.com/dns-query?name=$domain&type=A');
        final responseA = await http.get(
          urlA,
          headers: {
            'Accept': 'application/dns-json',
          },
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw Exception('DNS lookup timeout');
          },
        );

        if (responseA.statusCode == 200) {
          final dataA = json.decode(responseA.body);
          if (dataA['Answer'] != null && (dataA['Answer'] as List).isNotEmpty) {
            // Domain exists (has A records), even if no MX records
            // This is acceptable - some mail servers use A records
            return true;
          }
        }

        // No MX or A records found - domain likely doesn't exist
        return false;
      }

      return false;
    } catch (e) {
      print('Error checking domain existence: $e');
      // If DNS check fails, we'll assume it's a network issue
      // Return true to not block legitimate users
      return true;
    }
  }
}

