import 'dart:convert';
import 'dart:io';

import 'package:aes_crypt/aes_crypt.dart';
import 'package:flutter/material.dart';
import 'package:komodo_dex/model/addressbook_provider.dart';
import 'package:komodo_dex/model/backup.dart';
import 'package:komodo_dex/screens/import-export/export_import_success.dart';
import 'package:komodo_dex/widgets/password_visibility_control.dart';
import 'package:komodo_dex/widgets/primary_button.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';
import 'package:komodo_dex/model/export_import_list_item.dart';
import 'package:komodo_dex/services/db/database.dart';
import 'package:komodo_dex/localizations.dart';
import 'package:komodo_dex/screens/import-export/export_import_list.dart';

class ExportPage extends StatefulWidget {
  @override
  _ExportPageState createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _done = false;
  final TextEditingController _ctrlPass1 = TextEditingController();
  final TextEditingController _ctrlPass2 = TextEditingController();
  bool _isPassObscured = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final Backup _all = Backup(contacts: {}, notes: {});
  final Backup _selected = Backup(contacts: {}, notes: {});

  @override
  void initState() {
    _loadNotes();
    _loadContacts();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).exportTitle,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_done) ...{
              _buildSuccess(),
            } else ...{
              _buildHeader(),
              _buildNotes(),
              _buildContacts(),
              _buildPass(),
              _buildButton(),
            }
          ],
        ),
      ),
    );
  }

  Future<void> _loadNotes() async {
    final Map<String, String> notes = await Db.getAllNotes();

    setState(() {
      _all.notes = notes;
      _selected.notes = Map.from(_all.notes);
    });
  }

  Future<void> _loadContacts() async {
    final List<Contact> contacts =
        await Provider.of<AddressBookProvider>(context, listen: false).contacts;

    for (Contact contact in contacts) {
      setState(() {
        _all.contacts[contact.uid] = contact;
        _selected.contacts[contact.uid] = contact;
      });
    }
  }

  Widget _buildSuccess() {
    return ExportImportSuccess(
      title: AppLocalizations.of(context).exportSuccessTitle,
      items: {
        AppLocalizations.of(context).exportNotesTitle: _selected.notes.length,
        AppLocalizations.of(context).exportContactsTitle:
            _selected.contacts.length,
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 24, 12, 24),
      child: Text(AppLocalizations.of(context).exportDesc,
          style: TextStyle(
            height: 1.3,
            color: Theme.of(context).disabledColor,
          )),
    );
  }

  Widget _buildNotes() {
    if (_all.notes == null) return SizedBox();

    final List<ExportImportListItem> items = [];
    _all.notes.forEach((id, note) {
      items.add(ExportImportListItem(
          checked: _selected.notes.containsKey(id),
          onChange: (bool val) {
            setState(() {
              val ? _selected.notes[id] = note : _selected.notes.remove(id);
            });
          },
          child: Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.caption,
          )));
    });

    return ExportImportList(
      items: items,
      title: AppLocalizations.of(context).exportNotesTitle,
    );
  }

  Widget _buildContacts() {
    if (_all.contacts == null) return SizedBox();

    final List<ExportImportListItem> items = [];

    _all.contacts.forEach((uid, contact) {
      items.add(ExportImportListItem(
        checked: _selected.contacts.containsKey(uid),
        onChange: (val) {
          setState(() {
            val
                ? _selected.contacts[uid] = contact
                : _selected.contacts.remove(uid);
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact.name),
            SizedBox(height: 2),
            Builder(builder: (context) {
              final List<String> coins =
                  contact.addresses?.keys?.toList() ?? [];
              final List<Widget> coinsRow = [];

              for (int i = 0; i < coins.length; i++) {
                final String coin = coins[i];
                coinsRow.add(Text(
                  coin + (i < coins.length - 1 ? ', ' : ''),
                  style: TextStyle(
                      fontSize: 10, color: Theme.of(context).disabledColor),
                ));
              }

              return Wrap(
                children: coinsRow,
              );
            }),
          ],
        ),
      ));
    });

    return ExportImportList(
      title: AppLocalizations.of(context).exportContactsTitle,
      items: items,
    );
  }

  Widget _buildButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 24, 12, 48),
      child: Row(
        children: [
          Expanded(child: SizedBox()),
          Expanded(
            child: PrimaryButton(
              onPressed: () async {
                if (_validate()) _export();
              },
              text: AppLocalizations.of(context).exportButton,
            ),
          ),
          Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  bool _validate() {
    if (_selected.notes.isEmpty && _selected.contacts.isEmpty) {
      _showError(AppLocalizations.of(context).noItemsToExport);
      return false;
    }

    if (_ctrlPass1.text.isEmpty) {
      _showError(AppLocalizations.of(context).emptyExportPass);
      return false;
    }

    if (_ctrlPass1.text != _ctrlPass2.text) {
      _showError(AppLocalizations.of(context).matchExportPass);
      return false;
    }

    return true;
  }

  Future<void> _export() async {
    final Directory tmpDir = await getApplicationDocumentsDirectory();
    final crypt = AesCrypt(_ctrlPass1.text);

    final String encoded = jsonEncode(_selected);
    final tmpFilePath = '${tmpDir.path}/atomicDEX_backup';
    final File tempFile = File(tmpFilePath);
    if (tempFile.existsSync()) await tempFile.delete();
    await crypt.encryptTextToFile(encoded, tmpFilePath);

    await Share.shareFile(tempFile,
        mimeType: 'application/octet-stream', subject: 'atomicDEX_backup');
    tempFile.delete();
    setState(() {
      _done = true;
    });
  }

  Widget _buildPass() {
    return Container(
      color: Theme.of(context).primaryColor,
      padding: EdgeInsets.fromLTRB(12, 24, 12, 24),
      child: Column(children: [
        TextField(
          controller: _ctrlPass1,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableInteractiveSelection: true,
          toolbarOptions: ToolbarOptions(
            paste: _ctrlPass1.text.isEmpty,
            copy: false,
            cut: false,
            selectAll: false,
          ),
          obscureText: _isPassObscured,
          style: Theme.of(context).textTheme.bodyText2,
          decoration: InputDecoration(
            errorMaxLines: 6,
            errorStyle: Theme.of(context)
                .textTheme
                .bodyText2
                .copyWith(fontSize: 12, color: Theme.of(context).errorColor),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).primaryColorLight)),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).accentColor)),
            hintStyle: Theme.of(context).textTheme.bodyText1,
            labelStyle: Theme.of(context).textTheme.bodyText2,
            hintText: AppLocalizations.of(context).hintCreatePassword,
            labelText: null,
            suffixIcon: PasswordVisibilityControl(
              onVisibilityChange: (bool isPasswordObscured) {
                setState(() {
                  _isPassObscured = isPasswordObscured;
                });
              },
            ),
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        TextField(
          controller: _ctrlPass2,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          obscureText: _isPassObscured,
          enableInteractiveSelection: true,
          toolbarOptions: ToolbarOptions(
            paste: _ctrlPass2.text.isEmpty,
            copy: false,
            cut: false,
            selectAll: false,
          ),
          style: Theme.of(context).textTheme.bodyText2,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).primaryColorLight)),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).accentColor)),
            hintStyle: Theme.of(context).textTheme.bodyText1,
            labelStyle: Theme.of(context).textTheme.bodyText2,
            hintText: AppLocalizations.of(context).hintConfirmPassword,
            labelText: null,
          ),
        ),
      ]),
    );
  }

  void _showError(String e) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text(
      '$e',
      style: TextStyle(color: Theme.of(context).errorColor),
    )));
  }
}
