# encoding: utf-8

require File.join(File.dirname(__FILE__), 'test_helper.rb')

class RenderHTMLTest < Test::Unit::TestCase

  def reference_output(filename)
    IO.readlines(File.join(File.dirname(__FILE__), 'ref-output', filename)).join
  end

  # TODO: Enable this test
  # def test_render_default_html_invoice
  #   assert_equal reference_output('invoice1.html'), MyInvoice.find(1).render_html
  # end

  # TODO: Enable this test
  # def test_render_self_billed_html_invoice
  #   assert_equal reference_output('invoice2.html'), MyInvoice.find(2).render_html
  # end

  # TODO: Enable this test
  # def test_render_html_credit_note
  #   assert_equal reference_output('creditnote3.html'), MyCreditNote.find(3).render_html
  # end

  def test_render_with_custom_fragments
    expected = reference_output('invoice1.html').split("\n")[0..60]
    expected[0] = "<h1>INVOICE</h1>"
    expected[3] = "        <th class=\"recipient\">Customer</th>"
    expected[4] = "        <th class=\"sender\">Supplier</th>"
    expected[40] = "        <th>INVOICE no.:</th>"
    rendered = MyInvoice.find(1).render_html {|i|
      i.invoice_label{ "INVOICE" }
      i.sender_label "Supplier"
      i.recipient_label "Customer"
      i.title_tag {|param| "<h1>#{param[:title]}</h1>\n" }
      i.line_items_table {|param| ""}
    }
    assert_equal expected.join("\n") + "\n", rendered
  end

  # TODO: Enable this test
  # def test_render_empty_invoice
  #   invoice = MyInvoice.new
  #   invoice.line_items << SuperLineItem.new
  #   invoice.save!
  #   invoice.tax_amount = nil
  #   invoice.total_amount = nil
  #   rendered = invoice.render_html({:tax_point_column => true, :quantity_column => true,
  #     :description_column => true, :net_amount_column => true, :tax_amount_column => true,
  #     :gross_amount_column => true}) {|i| i.addresses_table{|x| ""}; i.description "foo" }
  #   assert_equal reference_output('invoice_null.html'), rendered
  # end

  def test_render_with_null_fragment
    assert_raise ArgumentError do
      MyInvoice.find(1).render_html do |i|
        i.invoice_label
      end
    end
  end

  def test_render_with_too_many_fragments
    assert_raise ArgumentError do
      MyInvoice.find(1).render_html do |i|
        i.invoice_label "a", "b"
      end
    end
  end

end
