# encoding: utf-8

require File.join(File.dirname(__FILE__), 'test_helper.rb')

class RenderUBLTest < Test::Unit::TestCase

  def reference_output(filename)
    IO.readlines(File.join(File.dirname(__FILE__), 'ref-output', filename)).join
  end

  # Compares two strings, each being a serialised XML document, while ignoring
  # the order of attributes within elements.
  # TODO: this could generate much nicer error messages on failure.
  def assert_equivalent_xml(doc1, doc2)
    doc1, doc2 = [doc1, doc2].map do |doc|
      doc.gsub(/(<[^\s>]+\s+)([^>]+)(>)/) do |match|
        $1.to_s + $2.to_s.split(/\s+/).sort.join(' ') + $3.to_s
      end
    end
    assert_equal doc1, doc2
  end

  # TODO: Enable this one
  # def test_render_ubl_invoice
  #   SuperLineItem.where("id > 8").destroy_all
  #   assert_equivalent_xml reference_output('invoice1.xml'), MyInvoice.find(1).render_ubl
  # end

  # TODO: Enable this one
  # def test_render_ubl_self_billed_invoice
  #   SuperLineItem.where("id > 8").destroy_all
  #   assert_equivalent_xml reference_output('invoice2.xml'), MyInvoice.find(2).render_ubl
  # end

  # TODO: Enable this one
  # def test_render_ubl_credit_note
  #   SuperLineItem.where("id > 8").destroy_all
  #   assert_equivalent_xml reference_output('creditnote3.xml'),  MyCreditNote.find(3).render_ubl
  # end

  def test_cannot_render_unknown_ledger_item_subtype
    assert_raise RuntimeError do
      CorporationTaxLiability.find(6).render_ubl
    end
  end
end
