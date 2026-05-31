$path = "D:\Projects\finance_app_zo\lib\features\payments\presentation\pages\today_payments_page.dart"
$lines = [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)
$out = New-Object System.Collections.Generic.List[string]
$state = "copy"
$depth = 0

foreach ($line in $lines) {
    if ($state -eq "skip") {
        foreach ($c in $line.ToCharArray()) {
            if ($c -eq '{') { $depth++ }
            elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { $state = "copy"; break } }
        }
        continue
    }

    if ($line -match '^\s+void _showSortSheet\(\)\s*\{') {
        $out.Add("  void _showSortSheet() {")
        $out.Add("    final filters = ref.read(paymentFilterProvider);")
        $out.Add("    showTodaySortSheet(context, filters.sortBy, (sort) {")
        $out.Add("      ref.read(paymentFilterProvider.notifier).setSortBy(sort);")
        $out.Add("    });")
        $out.Add("  }")
        $state = "skip"; $depth = 1; continue
    }
    if ($line -match '^\s+void _showShareSheet\(TodayPaymentData') {
        $out.Add("  void _showShareSheet(TodayPaymentData data) {")
        $out.Add("    final filters = ref.read(paymentFilterProvider);")
        $out.Add("    showTodayShareSheet(")
        $out.Add("      context, data, filters.dateLabel,")
        $out.Add("      () async {")
        $out.Add("        final text = PaymentExport.generateSummaryText(data, filters.dateLabel);")
        $out.Add('        await SharePlus.instance.share(ShareParams(text: text, subject: "Payments - ${filters.dateLabel}"));')
        $out.Add("      },")
        $out.Add("      () async {")
        $out.Add("        try { await PaymentExport.shareCsv(data.allPayments, filters.dateLabel); }")
        $out.Add('        catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.redAccent)); } }')
        $out.Add("      },")
        $out.Add("      () async {")
        $out.Add("        final text = PaymentExport.generateSummaryText(data, filters.dateLabel);")
        $out.Add("        await Clipboard.setData(ClipboardData(text: text));")
        $out.Add('        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Summary copied to clipboard"), backgroundColor: AppColors.success)); }')
        $out.Add("      },")
        $out.Add("    );")
        $out.Add("  }")
        $state = "skip"; $depth = 1; continue
    }
    if ($line -match '^\s+void _showPaymentDetails\(TodayPayment') {
        $out.Add("  void _showPaymentDetails(TodayPayment payment) {")
        $out.Add("    showTodayPaymentDetailSheet(")
        $out.Add("      context, payment,")
        $out.Add("      () => _makePhoneCall(payment.memberPhone!),")
        $out.Add("      () => _sendReminder(payment),")
        $out.Add("    );")
        $out.Add("  }")
        $state = "skip"; $depth = 1; continue
    }
    $out.Add($line)
}

# Add import after savings providers import
for ($i = 0; $i -lt $out.Count; $i++) {
    if ($out[$i] -match "savings.*providers") {
        $out.Insert($i+1, "import '../widgets/today_payment_widgets.dart';")
        break
    }
}

[System.IO.File]::WriteAllLines($path, $out, [System.Text.Encoding]::UTF8)
Write-Host "Done: $($out.Count) lines"
