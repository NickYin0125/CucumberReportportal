# language: zh-CN
@m3a @zh_cn
功能: M3A 中文元数据夹具
  功能描述第一行。
  功能描述第二行。

  背景: 共享中文上下文
    假如 共享的 M3A 功能上下文

  @chinese_rule
  规则: 中文规则元数据
    规则描述属于用例上下文。

    背景: 共享中文规则上下文
      规则背景描述。
      假如 共享的 M3A 上下文

    场景: 中文普通用例
      普通场景描述。
      假如 共享的 M3A 上下文
      当 我验证 M3A 表格 "ordinary":
        | key       | value | escaped | newline | trailing |
        | ordinary  | plain | A\|B    | line\nnext |         |
      那么 我验证 M3A 文档:
        """json
        {
          "record": "ordinary",
          "message": "line one\nline two",
          "slash": "path\\leaf",
          "template": "<not-a-parameter>",
          "fence": "```json"
        }
        """

    场景大纲: 中文示例用例 <record>
      <record> 的大纲描述。
      假如 共享的 M3A 上下文
      当 我验证 M3A 表格 "<record>":
        | key       | value   | escaped | newline | trailing |
        | <record>  | <value> | A\|B    | line\nnext |         |
      那么 我验证 M3A 文档:
        """json
        {
          "record": "<record>",
          "message": "line one\nline two",
          "slash": "path\\leaf",
          "template": "<template>",
          "fence": "```json"
        }
        """

      @zh_block
      例子: 中文示例数据
        | record | value | template |
        | 一组    | first | token-1  |
        | 二组    | second | token-2 |
