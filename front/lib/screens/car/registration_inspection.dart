import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'package:moring/providers/api_client.dart';
import 'package:moring/models/car.dart';
import 'package:moring/providers/current_car_provider.dart';
import 'package:moring/utils/base_scaffold.dart';

class InspectionRegistrationPage extends ConsumerStatefulWidget {
  final String vin;
  const InspectionRegistrationPage({Key? key, required this.vin}) : super(key: key);

  @override
  ConsumerState<InspectionRegistrationPage> createState() => _InspectionRegistrationPageState();
}

class _InspectionRegistrationPageState extends ConsumerState<InspectionRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _inadequateController = TextEditingController();
  final _recommendationController = TextEditingController();
  final _selfDiagnosisController = TextEditingController();
  final _specialNotesController = TextEditingController();

  bool _isSubmitting = false;
  Car? _car;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    DateTime initial = DateTime.tryParse(_dateController.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    // if (_car == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('차량 정보를 불러오지 못했습니다.')),
    //   );
    //   return;
    // }
    // if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final dio = ref.read(authDioProvider);
      final data = {
        "inspectionDate": _dateController.text,
        // "inadequateDetails": _inadequateController.text.isEmpty ? null : _inadequateController.text,
        // "recommendationDetails": _recommendationController.text.isEmpty ? null : _recommendationController.text,
        // "selfDiagnosis": _selfDiagnosisController.text.isEmpty ? null : _selfDiagnosisController.text,
        // "specialNotes": _specialNotesController.text.isEmpty ? null : _specialNotesController.text,
      };

      final resp = await dio.post(
        '/api/v1/cars/${widget.vin}/inspection',
        data: data,
        options: Options(contentType: 'application/json'),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록이 완료되었습니다!')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('에러 발생: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget buildExpandingField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 52, maxHeight: 200),
          child: TextFormField(
            controller: controller,
            minLines: 1,
            maxLines: null,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF23262B),
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white70),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    _dateController.dispose();
    // _inadequateController.dispose();
    // _recommendationController.dispose();
    // _selfDiagnosisController.dispose();
    // _specialNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // _car = ref.watch(currentCarProvider);

    return BaseScaffold(
      title: '점검 내역 등록',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 30, 18, 0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _dateController,
                readOnly: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onTap: _selectDate,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF23262B),
                  labelText: '점검 날짜',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, color: Colors.white54),
                    onPressed: _selectDate,
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? '날짜를 입력하세요' : null,
              ),
              // const SizedBox(height: 16),
              // buildExpandingField(_specialNotesController, '특기사항'),
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF50C878),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('등록하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
